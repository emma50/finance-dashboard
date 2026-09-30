-- ============================================================
-- Finance Dashboard
-- Migration: add_safe_financial_writes
--
-- Purpose:
--   Provide controlled, atomic write operations for financial
--   data.
--
-- Security model:
--
--   transactions/transfers are READ ONLY to the browser.
--
--   Financial writes happen through controlled PostgreSQL
--   functions invoked through Supabase RPC.
--
--   SECURITY DEFINER is intentional here because direct browser
--   INSERT/UPDATE/DELETE privileges on financial-event tables
--   have been revoked.
--
--   Each SECURITY DEFINER function:
--     - verifies auth.uid()
--     - uses search_path = ''
--     - schema-qualifies database objects
--     - receives EXECUTE only from authenticated
--     - has EXECUTE revoked from PUBLIC and anon
--
-- Financial guarantees:
--   - transaction creation is idempotent by primary-key UUID
--   - transaction lifecycle transitions are controlled
--   - transfer creation is atomic
--   - transfer completion/cancellation is atomic
--   - transfer always creates exactly two legs
--   - transfer legs cannot be independently transitioned
--
-- Deliberately excluded:
--   - transaction metadata editing
--   - refunds/reversals
--   - recurring transactions
--   - FX
--   - soft deletion
-- ============================================================


-- ============================================================
-- 1. Tighten account UPDATE privileges
--
-- opening_balance_minor and currency are historical/identity
-- properties and must not be changed by direct browser updates.
--
-- Direct client updates are therefore limited to:
--   - name
--   - type
--
-- Currency also has a database trigger preventing modification.
-- ============================================================

revoke update
on public.accounts
from authenticated;

grant update (name, type)
on public.accounts
to authenticated;


-- ============================================================
-- 2. Default function privilege hardening
--
-- Future public functions should not automatically become
-- callable through the Data API.
--
-- New functions must receive explicit EXECUTE grants.
-- ============================================================

alter default privileges in schema public
revoke execute on functions from public;

alter default privileges in schema public
revoke execute on functions from anon;

alter default privileges in schema public
revoke execute on functions from authenticated;


-- ============================================================
-- 3. Create a normal income/expense transaction
--
-- Transfer transactions MUST be created through
-- create_transfer().
--
-- p_transaction_id acts as the idempotency key.
--
-- The caller generates the UUID before invoking the RPC.
--
-- Repeating the same request with the same UUID returns the
-- existing transaction instead of creating another one.
-- ============================================================

create or replace function public.create_transaction(
    p_transaction_id uuid,
    p_account_id uuid,
    p_category_id uuid,
    p_type public.transaction_type,
    p_amount_minor bigint,
    p_merchant text default null,
    p_description text default null,
    p_occurred_at timestamptz default now(),
    p_status public.transaction_status default 'completed'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());

    v_existing public.transactions%rowtype;

    v_inserted_id uuid;
begin
    -- --------------------------------------------------------
    -- Authentication
    -- --------------------------------------------------------

    if v_user_id is null then
        raise exception
            using
                errcode = '42501',
                message = 'Authentication required';
    end if;


    -- --------------------------------------------------------
    -- Basic validation
    -- --------------------------------------------------------

    if p_transaction_id is null then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transaction ID is required';
    end if;


    if p_type = 'transfer' then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer transactions must be created through create_transfer';
    end if;


    if p_status = 'cancelled' then
        raise exception
            using
                errcode = 'P0001',
                message = 'A new transaction cannot be created as cancelled';
    end if;


    if p_amount_minor is null or p_amount_minor <= 0 then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transaction amount must be greater than zero';
    end if;


    if p_occurred_at is null then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transaction date is required';
    end if;


    if p_category_id is null then
        raise exception
            using
                errcode = 'P0001',
                message = 'Income and expense transactions require a category';
    end if;


    -- --------------------------------------------------------
    -- Verify that the account belongs to the authenticated
    -- user.
    -- --------------------------------------------------------

    if not exists (
        select 1
        from public.accounts
        where id = p_account_id
          and user_id = v_user_id
    ) then
        raise exception
            using
                errcode = '42501',
                message = 'Account not found';
    end if;


    -- --------------------------------------------------------
    -- Verify category ownership/type compatibility explicitly.
    --
    -- The composite FK also enforces this at the database level.
    -- This check gives the RPC a controlled business error.
    -- --------------------------------------------------------

    if not exists (
        select 1
        from public.categories
        where id = p_category_id
          and type = p_type
    ) then
        raise exception
            using
                errcode = 'P0001',
                message = 'Category is incompatible with transaction type';
    end if;


    -- --------------------------------------------------------
    -- Idempotent creation
    --
    -- If the UUID already exists, do not create a duplicate.
    -- --------------------------------------------------------

    insert into public.transactions (
        id,
        user_id,
        account_id,
        category_id,
        transfer_id,
        type,
        status,
        amount_minor,
        merchant,
        description,
        occurred_at
    )
    values (
        p_transaction_id,
        v_user_id,
        p_account_id,
        p_category_id,
        null,
        p_type,
        p_status,
        p_amount_minor,
        p_merchant,
        p_description,
        p_occurred_at
    )
    on conflict (id) do nothing
    returning id
    into v_inserted_id;


    if v_inserted_id is not null then
        return v_inserted_id;
    end if;


    -- --------------------------------------------------------
    -- The UUID already exists.
    --
    -- Fetch the existing operation and verify it belongs to
    -- this user and represents the same financial request.
    --
    -- Status is intentionally NOT compared because the existing
    -- transaction may have subsequently moved from pending to
    -- completed/cancelled.
    -- --------------------------------------------------------

    select *
    into v_existing
    from public.transactions
    where id = p_transaction_id;


    if not found then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transaction could not be created';
    end if;


    if v_existing.user_id <> v_user_id then
        raise exception
            using
                errcode = 'P0002',
                message = 'Transaction ID is already in use';
    end if;


    if v_existing.account_id is distinct from p_account_id
       or v_existing.category_id is distinct from p_category_id
       or v_existing.type is distinct from p_type
       or v_existing.amount_minor is distinct from p_amount_minor then

        raise exception
            using
                errcode = 'P0002',
                message = 'Transaction ID was reused with different financial data';
    end if;


    return v_existing.id;
end;
$$;


-- ============================================================
-- 4. Complete a normal transaction
--
-- Allowed:
--   pending -> completed
--
-- Idempotent:
--   completed -> completed
--
-- Forbidden:
--   cancelled -> completed
--   completed -> pending
--
-- Transfer legs cannot use this function.
-- ============================================================

create or replace function public.complete_transaction(
    p_transaction_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());

    v_status public.transaction_status;

    v_type public.transaction_type;
begin
    if v_user_id is null then
        raise exception
            using
                errcode = '42501',
                message = 'Authentication required';
    end if;


    select
        status,
        type
    into
        v_status,
        v_type
    from public.transactions
    where id = p_transaction_id
      and user_id = v_user_id
    for update;


    if not found then
        raise exception
            using
                errcode = '42501',
                message = 'Transaction not found';
    end if;


    if v_type = 'transfer' then
        raise exception
            using
                errcode = 'P0003',
                message = 'Transfer transactions must be transitioned through the transfer operation';
    end if;


    if v_status = 'completed' then
        return p_transaction_id;
    end if;


    if v_status = 'cancelled' then
        raise exception
            using
                errcode = 'P0003',
                message = 'A cancelled transaction cannot be completed';
    end if;


    update public.transactions
    set status = 'completed'
    where id = p_transaction_id
      and user_id = v_user_id
      and status = 'pending';


    if not found then
        raise exception
            using
                errcode = 'P0003',
                message = 'Transaction could not be completed';
    end if;


    return p_transaction_id;
end;
$$;


-- ============================================================
-- 5. Cancel a normal transaction
--
-- Allowed:
--   pending -> cancelled
--
-- Idempotent:
--   cancelled -> cancelled
--
-- Forbidden:
--   completed -> cancelled
--
-- Transfer legs cannot use this function.
-- ============================================================

create or replace function public.cancel_transaction(
    p_transaction_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());

    v_status public.transaction_status;

    v_type public.transaction_type;
begin
    if v_user_id is null then
        raise exception
            using
                errcode = '42501',
                message = 'Authentication required';
    end if;


    select
        status,
        type
    into
        v_status,
        v_type
    from public.transactions
    where id = p_transaction_id
      and user_id = v_user_id
    for update;


    if not found then
        raise exception
            using
                errcode = '42501',
                message = 'Transaction not found';
    end if;


    if v_type = 'transfer' then
        raise exception
            using
                errcode = 'P0003',
                message = 'Transfer transactions must be transitioned through the transfer operation';
    end if;


    if v_status = 'cancelled' then
        return p_transaction_id;
    end if;


    if v_status = 'completed' then
        raise exception
            using
                errcode = 'P0003',
                message = 'A completed transaction cannot be cancelled';
    end if;


    update public.transactions
    set status = 'cancelled'
    where id = p_transaction_id
      and user_id = v_user_id
      and status = 'pending';


    if not found then
        raise exception
            using
                errcode = 'P0003',
                message = 'Transaction could not be cancelled';
    end if;


    return p_transaction_id;
end;
$$;


-- ============================================================
-- 6. Create an atomic transfer
--
-- One logical operation creates:
--
--   transfer
--      +
--   source transaction
--      +
--   destination transaction
--
-- PostgreSQL executes the function within the caller's
-- transaction. Any exception rolls back the whole operation.
--
-- p_transfer_id acts as the idempotency key.
-- ============================================================

create or replace function public.create_transfer(
    p_transfer_id uuid,
    p_from_account_id uuid,
    p_to_account_id uuid,
    p_amount_minor bigint,
    p_occurred_at timestamptz default now(),
    p_status public.transaction_status default 'completed'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());

    v_source_currency varchar(3);

    v_destination_currency varchar(3);

    v_existing public.transfers%rowtype;

    v_inserted_id uuid;

    v_total_legs bigint;

    v_source_legs bigint;

    v_destination_legs bigint;
begin
    -- --------------------------------------------------------
    -- Authentication
    -- --------------------------------------------------------

    if v_user_id is null then
        raise exception
            using
                errcode = '42501',
                message = 'Authentication required';
    end if;


    -- --------------------------------------------------------
    -- Basic validation
    -- --------------------------------------------------------

    if p_transfer_id is null then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer ID is required';
    end if;


    if p_from_account_id is null
       or p_to_account_id is null then
        raise exception
            using
                errcode = 'P0001',
                message = 'Source and destination accounts are required';
    end if;


    if p_from_account_id = p_to_account_id then
        raise exception
            using
                errcode = 'P0001',
                message = 'Source and destination accounts must be different';
    end if;


    if p_amount_minor is null or p_amount_minor <= 0 then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer amount must be greater than zero';
    end if;


    if p_status = 'cancelled' then
        raise exception
            using
                errcode = 'P0001',
                message = 'A new transfer cannot be created as cancelled';
    end if;


    if p_occurred_at is null then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer date is required';
    end if;


    -- --------------------------------------------------------
    -- Confirm account ownership and retrieve currencies.
    --
    -- Cross-user transfers and cross-currency transfers are not
    -- supported in v1.
    -- --------------------------------------------------------

    select
        source_account.currency,
        destination_account.currency
    into
        v_source_currency,
        v_destination_currency
    from public.accounts as source_account
    join public.accounts as destination_account
        on destination_account.id = p_to_account_id
       and destination_account.user_id = v_user_id
    where source_account.id = p_from_account_id
      and source_account.user_id = v_user_id;


    if not found then
        raise exception
            using
                errcode = '42501',
                message = 'Source or destination account not found';
    end if;


    if v_source_currency <> v_destination_currency then
        raise exception
            using
                errcode = 'P0001',
                message = 'Cross-currency transfers are not supported';
    end if;


    -- --------------------------------------------------------
    -- Create the transfer itself.
    -- --------------------------------------------------------

    insert into public.transfers (
        id,
        user_id,
        from_account_id,
        to_account_id,
        amount_minor,
        status,
        occurred_at
    )
    values (
        p_transfer_id,
        v_user_id,
        p_from_account_id,
        p_to_account_id,
        p_amount_minor,
        p_status,
        p_occurred_at
    )
    on conflict (id) do nothing
    returning id
    into v_inserted_id;


    -- --------------------------------------------------------
    -- Normal creation path.
    -- --------------------------------------------------------

    if v_inserted_id is not null then

        -- Source leg.
        insert into public.transactions (
            user_id,
            account_id,
            category_id,
            transfer_id,
            type,
            status,
            amount_minor,
            merchant,
            description,
            occurred_at
        )
        values (
            v_user_id,
            p_from_account_id,
            null,
            p_transfer_id,
            'transfer',
            p_status,
            p_amount_minor,
            null,
            'Transfer to account',
            p_occurred_at
        );


        -- Destination leg.
        insert into public.transactions (
            user_id,
            account_id,
            category_id,
            transfer_id,
            type,
            status,
            amount_minor,
            merchant,
            description,
            occurred_at
        )
        values (
            v_user_id,
            p_to_account_id,
            null,
            p_transfer_id,
            'transfer',
            p_status,
            p_amount_minor,
            null,
            'Transfer from account',
            p_occurred_at
        );


        return v_inserted_id;
    end if;


    -- --------------------------------------------------------
    -- Idempotent retry path.
    --
    -- The transfer already exists. Confirm that this UUID still
    -- represents the same financial operation.
    -- --------------------------------------------------------

    select *
    into v_existing
    from public.transfers
    where id = p_transfer_id;


    if not found then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer could not be created';
    end if;


    if v_existing.user_id <> v_user_id then
        raise exception
            using
                errcode = 'P0002',
                message = 'Transfer ID is already in use';
    end if;


    if v_existing.from_account_id is distinct from p_from_account_id
       or v_existing.to_account_id is distinct from p_to_account_id
       or v_existing.amount_minor is distinct from p_amount_minor then

        raise exception
            using
                errcode = 'P0002',
                message = 'Transfer ID was reused with different financial data';
    end if;


    -- --------------------------------------------------------
    -- A valid transfer must have exactly one source leg and one
    -- destination leg.
    -- --------------------------------------------------------

    select
        count(*),
        count(*) filter (
            where account_id = v_existing.from_account_id
        ),
        count(*) filter (
            where account_id = v_existing.to_account_id
        )
    into
        v_total_legs,
        v_source_legs,
        v_destination_legs
    from public.transactions
    where transfer_id = p_transfer_id
      and user_id = v_user_id
      and type = 'transfer'
      and category_id is null
      and amount_minor = v_existing.amount_minor
      and status = v_existing.status;


    if v_total_legs <> 2
       or v_source_legs <> 1
       or v_destination_legs <> 1 then
        raise exception
            using
                errcode = 'P0001',
                message = 'Existing transfer does not have a valid two-leg structure';
    end if;


    return v_existing.id;
end;
$$;


-- ============================================================
-- 7. Complete an atomic transfer
--
-- Allowed:
--   pending -> completed
--
-- Idempotent:
--   completed -> completed
--
-- Forbidden:
--   cancelled -> completed
--
-- Both transaction legs transition together.
-- ============================================================

create or replace function public.complete_transfer(
    p_transfer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());

    v_status public.transaction_status;

    v_from_account_id uuid;

    v_to_account_id uuid;

    v_amount_minor bigint;

    v_total_legs bigint;

    v_source_legs bigint;

    v_destination_legs bigint;

    v_valid_pending_legs bigint;

    v_updated_count bigint;
begin
    if v_user_id is null then
        raise exception
            using
                errcode = '42501',
                message = 'Authentication required';
    end if;


    -- Lock the transfer row so completion and cancellation cannot
    -- race each other.
    select
        status,
        from_account_id,
        to_account_id,
        amount_minor
    into
        v_status,
        v_from_account_id,
        v_to_account_id,
        v_amount_minor
    from public.transfers
    where id = p_transfer_id
      and user_id = v_user_id
    for update;


    if not found then
        raise exception
            using
                errcode = '42501',
                message = 'Transfer not found';
    end if;


    if v_status = 'completed' then
        return p_transfer_id;
    end if;


    if v_status = 'cancelled' then
        raise exception
            using
                errcode = 'P0003',
                message = 'A cancelled transfer cannot be completed';
    end if;


    -- Lock both transfer legs before changing either one.
    perform 1
    from public.transactions
    where transfer_id = p_transfer_id
      and user_id = v_user_id
    for update;


    -- Validate the two-leg structure before modifying anything.
    select
        count(*),
        count(*) filter (
            where account_id = v_from_account_id
              and type = 'transfer'
              and category_id is null
              and amount_minor = v_amount_minor
        ),
        count(*) filter (
            where account_id = v_to_account_id
              and type = 'transfer'
              and category_id is null
              and amount_minor = v_amount_minor
        ),
        count(*) filter (
            where type = 'transfer'
              and category_id is null
              and amount_minor = v_amount_minor
              and status = 'pending'
        )
    into
        v_total_legs,
        v_source_legs,
        v_destination_legs,
        v_valid_pending_legs
    from public.transactions
    where transfer_id = p_transfer_id
      and user_id = v_user_id;


    if v_total_legs <> 2
       or v_source_legs <> 1
       or v_destination_legs <> 1
       or v_valid_pending_legs <> 2 then

        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer does not have a valid pending two-leg structure';
    end if;


    -- Complete both legs.
    update public.transactions
    set status = 'completed'
    where transfer_id = p_transfer_id
      and user_id = v_user_id
      and status = 'pending';


    get diagnostics v_updated_count = row_count;


    if v_updated_count <> 2 then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer legs could not be completed atomically';
    end if;


    -- Only after both legs have been updated do we complete the
    -- transfer record itself.
    update public.transfers
    set status = 'completed'
    where id = p_transfer_id
      and user_id = v_user_id
      and status = 'pending';


    if not found then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer could not be completed atomically';
    end if;


    return p_transfer_id;
end;
$$;


-- ============================================================
-- 8. Cancel an atomic transfer
--
-- Allowed:
--   pending -> cancelled
--
-- Idempotent:
--   cancelled -> cancelled
--
-- Forbidden:
--   completed -> cancelled
--
-- Both transaction legs transition together.
-- ============================================================

create or replace function public.cancel_transfer(
    p_transfer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());

    v_status public.transaction_status;

    v_from_account_id uuid;

    v_to_account_id uuid;

    v_amount_minor bigint;

    v_total_legs bigint;

    v_source_legs bigint;

    v_destination_legs bigint;

    v_valid_pending_legs bigint;

    v_updated_count bigint;
begin
    if v_user_id is null then
        raise exception
            using
                errcode = '42501',
                message = 'Authentication required';
    end if;


    -- Lock the transfer row to serialize lifecycle transitions.
    select
        status,
        from_account_id,
        to_account_id,
        amount_minor
    into
        v_status,
        v_from_account_id,
        v_to_account_id,
        v_amount_minor
    from public.transfers
    where id = p_transfer_id
      and user_id = v_user_id
    for update;


    if not found then
        raise exception
            using
                errcode = '42501',
                message = 'Transfer not found';
    end if;


    if v_status = 'cancelled' then
        return p_transfer_id;
    end if;


    if v_status = 'completed' then
        raise exception
            using
                errcode = 'P0003',
                message = 'A completed transfer cannot be cancelled';
    end if;


    -- Lock both legs before changing either one.
    perform 1
    from public.transactions
    where transfer_id = p_transfer_id
      and user_id = v_user_id
    for update;


    -- Validate the transfer structure before modifying it.
    select
        count(*),
        count(*) filter (
            where account_id = v_from_account_id
              and type = 'transfer'
              and category_id is null
              and amount_minor = v_amount_minor
        ),
        count(*) filter (
            where account_id = v_to_account_id
              and type = 'transfer'
              and category_id is null
              and amount_minor = v_amount_minor
        ),
        count(*) filter (
            where type = 'transfer'
              and category_id is null
              and amount_minor = v_amount_minor
              and status = 'pending'
        )
    into
        v_total_legs,
        v_source_legs,
        v_destination_legs,
        v_valid_pending_legs
    from public.transactions
    where transfer_id = p_transfer_id
      and user_id = v_user_id;


    if v_total_legs <> 2
       or v_source_legs <> 1
       or v_destination_legs <> 1
       or v_valid_pending_legs <> 2 then

        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer does not have a valid pending two-leg structure';
    end if;


    -- Cancel both legs.
    update public.transactions
    set status = 'cancelled'
    where transfer_id = p_transfer_id
      and user_id = v_user_id
      and status = 'pending';


    get diagnostics v_updated_count = row_count;


    if v_updated_count <> 2 then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer legs could not be cancelled atomically';
    end if;


    -- Cancel the transfer only after both transaction legs have
    -- been successfully cancelled.
    update public.transfers
    set status = 'cancelled'
    where id = p_transfer_id
      and user_id = v_user_id
      and status = 'pending';


    if not found then
        raise exception
            using
                errcode = 'P0001',
                message = 'Transfer could not be cancelled atomically';
    end if;


    return p_transfer_id;
end;
$$;


-- ============================================================
-- 9. Lock down function execution
--
-- PostgreSQL functions otherwise receive EXECUTE to PUBLIC by
-- default.
--
-- We explicitly remove that access and grant only to
-- authenticated clients.
-- ============================================================


-- create_transaction
revoke execute
on function public.create_transaction(
    uuid,
    uuid,
    uuid,
    public.transaction_type,
    bigint,
    text,
    text,
    timestamptz,
    public.transaction_status
)
from public, anon;

grant execute
on function public.create_transaction(
    uuid,
    uuid,
    uuid,
    public.transaction_type,
    bigint,
    text,
    text,
    timestamptz,
    public.transaction_status
)
to authenticated;


-- complete_transaction
revoke execute
on function public.complete_transaction(uuid)
from public, anon;

grant execute
on function public.complete_transaction(uuid)
to authenticated;


-- cancel_transaction
revoke execute
on function public.cancel_transaction(uuid)
from public, anon;

grant execute
on function public.cancel_transaction(uuid)
to authenticated;


-- create_transfer
revoke execute
on function public.create_transfer(
    uuid,
    uuid,
    uuid,
    bigint,
    timestamptz,
    public.transaction_status
)
from public, anon;

grant execute
on function public.create_transfer(
    uuid,
    uuid,
    uuid,
    bigint,
    timestamptz,
    public.transaction_status
)
to authenticated;


-- complete_transfer
revoke execute
on function public.complete_transfer(uuid)
from public, anon;

grant execute
on function public.complete_transfer(uuid)
to authenticated;


-- cancel_transfer
revoke execute
on function public.cancel_transfer(uuid)
from public, anon;

grant execute
on function public.cancel_transfer(uuid)
to authenticated;