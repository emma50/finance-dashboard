-- ============================================================
-- Finance Dashboard
-- Database / RLS / Financial Write Tests
--
-- Purpose:
--   Attack the security and financial-integrity boundaries of
--   the finance database.
--
-- Test runner:
--   pgTAP via `supabase test db`
--
-- Important:
--   This entire file runs inside a transaction and is rolled back
--   at the end. Test fixtures never become application data.
--
-- Coverage:
--   1. RLS enabled
--   2. Anonymous read denied
--   3. Anonymous RPC execution denied
--   4. User isolation
--   5. Cross-user account creation denied
--   6. Cross-user transaction denied
--   7. Category/type integrity
--   8. Direct transaction lifecycle mutation denied
--   9. Valid transaction lifecycle
--  10. Invalid transaction lifecycle
--  11. Transfer structure integrity
--  12. Cross-user transfers
--  13. Cross-currency transfers
--  14. Idempotent transaction creation
--  15. Idempotent transfer creation
--  16. Atomic transfer rollback
-- ============================================================


begin;


-- ============================================================
-- 1. Test environment
-- ============================================================

create extension if not exists pgtap with schema extensions;

set local search_path = public, extensions;


-- ============================================================
-- 2. Test plan
--
-- Keep this explicit.
-- If a new test is added, update the plan deliberately.
-- ============================================================

select plan(33);


-- ============================================================
-- 3. Stable test IDs
--
-- Deterministic UUIDs make failures reproducible and easier
-- to reason about.
-- ============================================================

create temp table finance_test_ids (
    user_a uuid not null,
    user_b uuid not null,

    account_a_current uuid not null,
    account_a_savings uuid not null,
    account_a_usd uuid not null,
    account_b_current uuid not null,

    category_salary uuid not null,
    category_food uuid not null,
    category_transport uuid not null,

    transaction_completed uuid not null,
    transaction_pending uuid not null,
    transaction_cancelled uuid not null,
    transaction_user_b uuid not null,

    transaction_invalid_category uuid not null,
    transaction_invalid_status uuid not null,
    transaction_duplicate uuid not null,

    transfer_one_leg uuid not null,
    transfer_one_leg_source uuid not null,

    transfer_wrong_amount uuid not null,
    transfer_wrong_amount_source uuid not null,
    transfer_wrong_amount_destination uuid not null,

    transfer_duplicate uuid not null,
    transaction_duplicate_source uuid not null,
    transaction_duplicate_destination uuid not null,

    transfer_atomic_rollback uuid not null,
    transaction_atomic_source uuid not null,
    transaction_atomic_destination uuid not null
) on commit drop;


insert into finance_test_ids (
    user_a,
    user_b,

    account_a_current,
    account_a_savings,
    account_a_usd,
    account_b_current,

    category_salary,
    category_food,
    category_transport,

    transaction_completed,
    transaction_pending,
    transaction_cancelled,
    transaction_user_b,

    transaction_invalid_category,
    transaction_invalid_status,
    transaction_duplicate,

    transfer_one_leg,
    transfer_one_leg_source,

    transfer_wrong_amount,
    transfer_wrong_amount_source,
    transfer_wrong_amount_destination,

    transfer_duplicate,
    transaction_duplicate_source,
    transaction_duplicate_destination,

    transfer_atomic_rollback,
    transaction_atomic_source,
    transaction_atomic_destination
)
values (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',

    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000201',

    '00000000-0000-0000-0000-000000000301',
    '00000000-0000-0000-0000-000000000302',
    '00000000-0000-0000-0000-000000000303',

    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000402',
    '00000000-0000-0000-0000-000000000403',
    '00000000-0000-0000-0000-000000000404',

    '00000000-0000-0000-0000-000000000405',
    '00000000-0000-0000-0000-000000000406',
    '00000000-0000-0000-0000-000000000407',

    '00000000-0000-0000-0000-000000000501',
    '00000000-0000-0000-0000-000000000601',

    '00000000-0000-0000-0000-000000000502',
    '00000000-0000-0000-0000-000000000602',
    '00000000-0000-0000-0000-000000000603',

    '00000000-0000-0000-0000-000000000503',
    '00000000-0000-0000-0000-000000000604',
    '00000000-0000-0000-0000-000000000605',

    '00000000-0000-0000-0000-000000000504',
    '00000000-0000-0000-0000-000000000606',
    '00000000-0000-0000-0000-000000000607'
);


-- ============================================================
-- 4. Create test users
--
-- We create auth.users directly because the test runner is
-- operating as the database owner.
--
-- These records are rolled back at the end of the test.
-- ============================================================

insert into auth.users (
    id,
    email
)
select
    ids.user_a,
    'finance-test-user-a@example.com'
from finance_test_ids ids;


insert into auth.users (
    id,
    email
)
select
    ids.user_b,
    'finance-test-user-b@example.com'
from finance_test_ids ids;


-- ============================================================
-- 5. Profiles
-- ============================================================

insert into public.profiles (
    id,
    display_name,
    default_currency,
    timezone
)
select
    ids.user_a,
    'Finance Test User A',
    'NGN',
    'Africa/Lagos'
from finance_test_ids ids;


insert into public.profiles (
    id,
    display_name,
    default_currency,
    timezone
)
select
    ids.user_b,
    'Finance Test User B',
    'NGN',
    'Africa/Lagos'
from finance_test_ids ids;


-- ============================================================
-- 6. Accounts
-- ============================================================

insert into public.accounts (
    id,
    user_id,
    name,
    type,
    currency,
    opening_balance_minor
)
select
    ids.account_a_current,
    ids.user_a,
    'User A Current',
    'current',
    'NGN',
    50000000
from finance_test_ids ids;


insert into public.accounts (
    id,
    user_id,
    name,
    type,
    currency,
    opening_balance_minor
)
select
    ids.account_a_savings,
    ids.user_a,
    'User A Savings',
    'savings',
    'NGN',
    10000000
from finance_test_ids ids;


insert into public.accounts (
    id,
    user_id,
    name,
    type,
    currency,
    opening_balance_minor
)
select
    ids.account_a_usd,
    ids.user_a,
    'User A USD',
    'current',
    'USD',
    1000000
from finance_test_ids ids;


insert into public.accounts (
    id,
    user_id,
    name,
    type,
    currency,
    opening_balance_minor
)
select
    ids.account_b_current,
    ids.user_b,
    'User B Current',
    'current',
    'NGN',
    30000000
from finance_test_ids ids;


-- ============================================================
-- 7. Categories
-- ============================================================

insert into public.categories (
    id,
    name,
    type
)
select
    ids.category_salary,
    'Salary',
    'income'
from finance_test_ids ids;


insert into public.categories (
    id,
    name,
    type
)
select
    ids.category_food,
    'Food',
    'expense'
from finance_test_ids ids;


insert into public.categories (
    id,
    name,
    type
)
select
    ids.category_transport,
    'Transport',
    'expense'
from finance_test_ids ids;


-- ============================================================
-- 8. Initial transactions
--
-- These fixtures are deliberately created as the database owner
-- so they bypass RLS during test setup.
-- ============================================================

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
select
    ids.transaction_completed,
    ids.user_a,
    ids.account_a_current,
    ids.category_food,
    null,
    'expense',
    'completed',
    500000,
    'Test Supermarket',
    'Completed expense',
    now()
from finance_test_ids ids;


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
select
    ids.transaction_pending,
    ids.user_a,
    ids.account_a_current,
    ids.category_food,
    null,
    'expense',
    'pending',
    250000,
    'Pending Merchant',
    'Pending expense',
    now()
from finance_test_ids ids;


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
select
    ids.transaction_cancelled,
    ids.user_a,
    ids.account_a_current,
    ids.category_transport,
    null,
    'expense',
    'cancelled',
    100000,
    'Cancelled Merchant',
    'Cancelled expense',
    now()
from finance_test_ids ids;


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
select
    ids.transaction_user_b,
    ids.user_b,
    ids.account_b_current,
    ids.category_food,
    null,
    'expense',
    'completed',
    700000,
    'User B Merchant',
    'User B transaction',
    now()
from finance_test_ids ids;


-- ============================================================
-- 9. Malformed transfer fixture #1
--
-- Transfer has only ONE transaction leg.
--
-- The application should never create this state, but our
-- database test deliberately constructs it to verify that the
-- lifecycle operation refuses to continue with corrupt state.
-- ============================================================

insert into public.transfers (
    id,
    user_id,
    from_account_id,
    to_account_id,
    amount_minor,
    status,
    occurred_at
)
select
    ids.transfer_one_leg,
    ids.user_a,
    ids.account_a_current,
    ids.account_a_savings,
    10000000,
    'pending',
    now()
from finance_test_ids ids;


insert into public.transactions (
    id,
    user_id,
    account_id,
    category_id,
    transfer_id,
    type,
    status,
    amount_minor,
    occurred_at
)
select
    ids.transfer_one_leg_source,
    ids.user_a,
    ids.account_a_current,
    null,
    ids.transfer_one_leg,
    'transfer',
    'pending',
    10000000,
    now()
from finance_test_ids ids;


-- ============================================================
-- 10. Malformed transfer fixture #2
--
-- Transfer amount = 15,000,000
-- Source leg      = 15,000,000
-- Destination     = 12,500,000
--
-- The two transaction legs do not represent the same operation.
-- ============================================================

insert into public.transfers (
    id,
    user_id,
    from_account_id,
    to_account_id,
    amount_minor,
    status,
    occurred_at
)
select
    ids.transfer_wrong_amount,
    ids.user_a,
    ids.account_a_current,
    ids.account_a_savings,
    15000000,
    'pending',
    now()
from finance_test_ids ids;


insert into public.transactions (
    id,
    user_id,
    account_id,
    category_id,
    transfer_id,
    type,
    status,
    amount_minor,
    occurred_at
)
select
    ids.transfer_wrong_amount_source,
    ids.user_a,
    ids.account_a_current,
    null,
    ids.transfer_wrong_amount,
    'transfer',
    'pending',
    15000000,
    now()
from finance_test_ids ids;


insert into public.transactions (
    id,
    user_id,
    account_id,
    category_id,
    transfer_id,
    type,
    status,
    amount_minor,
    occurred_at
)
select
    ids.transfer_wrong_amount_destination,
    ids.user_a,
    ids.account_a_savings,
    null,
    ids.transfer_wrong_amount,
    'transfer',
    'pending',
    12500000,
    now()
from finance_test_ids ids;


-- ============================================================
-- 11. Atomic rollback fixture
--
-- This transfer is structurally valid.
--
-- We deliberately install a test-only trigger that fails when
-- the transfer itself is updated to completed.
--
-- complete_transfer() will:
--
--   1. lock transfer
--   2. lock both legs
--   3. complete both legs
--   4. attempt to complete transfer
--   5. trigger failure
--   6. PostgreSQL rolls the entire function call back
--
-- This proves atomicity instead of merely inspecting the happy
-- path.
-- ============================================================

insert into public.transfers (
    id,
    user_id,
    from_account_id,
    to_account_id,
    amount_minor,
    status,
    occurred_at
)
select
    ids.transfer_atomic_rollback,
    ids.user_a,
    ids.account_a_current,
    ids.account_a_savings,
    5000000,
    'pending',
    now()
from finance_test_ids ids;


insert into public.transactions (
    id,
    user_id,
    account_id,
    category_id,
    transfer_id,
    type,
    status,
    amount_minor,
    occurred_at
)
select
    ids.transaction_atomic_source,
    ids.user_a,
    ids.account_a_current,
    null,
    ids.transfer_atomic_rollback,
    'transfer',
    'pending',
    5000000,
    now()
from finance_test_ids ids;


insert into public.transactions (
    id,
    user_id,
    account_id,
    category_id,
    transfer_id,
    type,
    status,
    amount_minor,
    occurred_at
)
select
    ids.transaction_atomic_destination,
    ids.user_a,
    ids.account_a_savings,
    null,
    ids.transfer_atomic_rollback,
    'transfer',
    'pending',
    5000000,
    now()
from finance_test_ids ids;


-- ============================================================
-- 12. Test-only failure trigger
-- ============================================================

create schema if not exists test_support;


create or replace function test_support.fail_atomic_transfer_completion()
returns trigger
language plpgsql
as $$
begin
    if new.id = '00000000-0000-0000-0000-000000000504'::uuid
       and old.status = 'pending'
       and new.status = 'completed' then

        raise exception
            using
                errcode = 'P0001',
                message = 'Intentional test failure during transfer completion';
    end if;

    return new;
end;
$$;


create trigger test_fail_atomic_transfer_completion
before update of status
on public.transfers
for each row
execute function test_support.fail_atomic_transfer_completion();


-- ============================================================
-- 13. Structural security checks
-- ============================================================


-- Test 1
select is(
    (
        select count(*)::integer
        from pg_tables
        where schemaname = 'public'
          and tablename in (
              'profiles',
              'accounts',
              'categories',
              'transfers',
              'transactions',
              'budgets'
          )
          and rowsecurity
    ),
    6,
    'RLS is enabled on every finance table'
);


-- Test 2
select ok(
    not has_table_privilege(
        'anon',
        'public.transactions',
        'SELECT'
    ),
    'Anonymous clients do not have SELECT privilege on transactions'
);


-- Test 4
select ok(
    not has_function_privilege(
        'anon',
        'public.create_transaction(
            uuid,
            uuid,
            uuid,
            public.transaction_type,
            bigint,
            text,
            text,
            timestamptz,
            public.transaction_status
        )',
        'EXECUTE'
    ),
    'Anonymous clients cannot execute create_transaction'
);


-- Test 5
select ok(
    has_function_privilege(
        'authenticated',
        'public.create_transaction(
            uuid,
            uuid,
            uuid,
            public.transaction_type,
            bigint,
            text,
            text,
            timestamptz,
            public.transaction_status
        )',
        'EXECUTE'
    ),
    'Authenticated clients can execute create_transaction'
);


-- ============================================================
-- 14. Anonymous read test
--
-- We actually switch to anon here so we test the request path,
-- not just the ACL metadata.
--
-- RESET ROLE returns to the original postgres session role.
-- ============================================================

set local role anon;


-- Test 3
select throws_ok(
    $$select count(*) from public.transactions$$,
    '42501',
    null,
    'Anonymous clients cannot read transactions'
);


reset role;


-- ============================================================
-- 15. Authenticate as User A
-- ============================================================

set local role authenticated;

set local request.jwt.claim.sub =
    '00000000-0000-0000-0000-000000000001';


-- ============================================================
-- 16. RLS isolation
-- ============================================================


-- Test 6
select ok(
  (
    select count(*)
    from public.transactions
    where user_id = '00000000-0000-0000-0000-000000000001'::uuid
  ) > 0,
  'User A can see their own transactions'
);

-- Test 7
select results_eq(
    $$
        select count(*)
        from public.transactions
        where user_id =
            '00000000-0000-0000-0000-000000000002'::uuid
    $$,
    $$values (0::bigint)$$,
    'User A cannot see User B transactions'
);


-- ============================================================
-- 17. Cross-user account protection
-- ============================================================


-- Test 8
select throws_ok(
    $$
        insert into public.accounts (
            user_id,
            name,
            type,
            currency,
            opening_balance_minor
        )
        values (
            '00000000-0000-0000-0000-000000000002'::uuid,
            'Forged User B Account',
            'current',
            'NGN',
            0
        )
    $$,
    '42501',
    null,
    'User A cannot create an account owned by User B'
);


-- ============================================================
-- 18. Cross-user transaction protection
--
-- User A controls the RPC call but supplies User B's account.
-- The function must reject it.
-- ============================================================


-- Test 9
select throws_ok(
    $$
        select public.create_transaction(
            '00000000-0000-0000-0000-000000000408'::uuid,
            '00000000-0000-0000-0000-000000000201'::uuid,
            '00000000-0000-0000-0000-000000000302'::uuid,
            'expense'::public.transaction_type,
            100000,
            'Unauthorized Merchant',
            'Cross-user transaction attempt',
            now(),
            'completed'::public.transaction_status
        )
    $$,
    '42501',
    'Account not found',
    'User A cannot create a transaction against User B account'
);


-- ============================================================
-- 19. Structural transaction/category integrity
--
-- This is executed after setup but still as the postgres session
-- role because the authenticated client has no direct INSERT
-- privilege on transactions.
--
-- The invalid combination is:
--
--   transaction.type = expense
--   category.type    = income
--
-- The composite FK should reject it.
-- ============================================================

reset role;


-- Test 10
select throws_ok(
    $$
        insert into public.transactions (
            id,
            user_id,
            account_id,
            category_id,
            transfer_id,
            type,
            status,
            amount_minor,
            occurred_at
        )
        values (
            (
                select transaction_invalid_category
                from finance_test_ids
            ),
            (
                select user_a
                from finance_test_ids
            ),
            (
                select account_a_current
                from finance_test_ids
            ),
            (
                select category_salary
                from finance_test_ids
            ),
            null,
            'expense'::public.transaction_type,
            'completed'::public.transaction_status,
            100000,
            now()
        )
    $$,
    '23503',
    null,
    'Expense transaction cannot reference an income category'
);


-- Return to User A.
set local role authenticated;

set local request.jwt.claim.sub =
    '00000000-0000-0000-0000-000000000001';


-- ============================================================
-- 20. Direct financial mutation protection
-- ============================================================


-- Test 11
select throws_ok(
    $$
        update public.transactions
        set status = 'pending'
        where id = '00000000-0000-0000-0000-000000000401'::uuid
    $$,
    '42501',
    null,
    'Browser clients cannot directly modify transaction lifecycle'
);


-- ============================================================
-- 21. Valid transaction lifecycle
-- ============================================================


-- Test 12
select is(
    (
        select public.complete_transaction(
            '00000000-0000-0000-0000-000000000402'::uuid
        )::text
    ),
    '00000000-0000-0000-0000-000000000402',
    'Pending transaction can be completed'
);


-- Test 13
select is(
    (
        select status::text
        from public.transactions
        where id = '00000000-0000-0000-0000-000000000402'::uuid
    ),
    'completed',
    'Completed transaction has completed status'
);


-- ============================================================
-- 22. Invalid transaction lifecycle
-- ============================================================


-- Test 14
select throws_ok(
    $$
        select public.cancel_transaction(
            '00000000-0000-0000-0000-000000000401'::uuid
        )
    $$,
    'P0003',
    'A completed transaction cannot be cancelled',
    'Completed transaction cannot transition to cancelled'
);


-- Test 15
select throws_ok(
    $$
        select public.complete_transaction(
            '00000000-0000-0000-0000-000000000403'::uuid
        )
    $$,
    'P0003',
    'A cancelled transaction cannot be completed',
    'Cancelled transaction cannot transition to completed'
);


-- Test 16
select throws_ok(
    $$
        select public.create_transaction(
            '00000000-0000-0000-0000-000000000406'::uuid,
            '00000000-0000-0000-0000-000000000001'::uuid,
            '00000000-0000-0000-0000-000000000302'::uuid,
            'expense'::public.transaction_type,
            100000,
            'Invalid Status Transaction',
            null,
            now(),
            'cancelled'::public.transaction_status
        )
    $$,
    'P0001',
    'A new transaction cannot be created as cancelled',
    'A new transaction cannot start in cancelled state'
);


-- ============================================================
-- 23. Transfer with one leg
-- ============================================================


-- Test 17
select throws_ok(
    $$
        select public.complete_transfer(
            '00000000-0000-0000-0000-000000000501'::uuid
        )
    $$,
    'P0001',
    'Transfer does not have a valid pending two-leg structure',
    'Transfer with one transaction leg must be rejected'
);


-- Test 18
select results_eq(
    $$
        select
            (select status::text
             from public.transfers
             where id =
                 '00000000-0000-0000-0000-000000000501'::uuid)
    $$,
    $$values ('pending')$$,
    'Rejected one-leg transfer remains pending'
);


-- ============================================================
-- 24. Transfer with wrong amount
-- ============================================================


-- Test 19
select throws_ok(
    $$
        select public.complete_transfer(
            '00000000-0000-0000-0000-000000000502'::uuid
        )
    $$,
    'P0001',
    'Transfer does not have a valid pending two-leg structure',
    'Transfer with mismatched leg amount must be rejected'
);


-- Test 20
select results_eq(
    $$
        select
            count(*) filter (where status = 'pending'),
            count(*) filter (where status = 'completed'),
            count(*) filter (where status = 'cancelled')
        from public.transactions
        where transfer_id =
            '00000000-0000-0000-0000-000000000502'::uuid
    $$,
    $$values (2::bigint, 0::bigint, 0::bigint)$$,
    'Rejected mismatched transfer leaves both legs pending'
);


-- ============================================================
-- 25. Transfer ownership and currency protection
-- ============================================================


-- Test 21
select throws_ok(
    $$
        select public.create_transfer(
            '00000000-0000-0000-0000-000000000507'::uuid,
            '00000000-0000-0000-0000-000000000101'::uuid,
            '00000000-0000-0000-0000-000000000201'::uuid,
            100000,
            now(),
            'completed'::public.transaction_status
        )
    $$,
    '42501',
    'Source or destination account not found',
    'User A cannot create a transfer to User B account'
);


-- Test 22
select throws_ok(
    $$
        select public.create_transfer(
            '00000000-0000-0000-0000-000000000508'::uuid,
            '00000000-0000-0000-0000-000000000101'::uuid,
            '00000000-0000-0000-0000-000000000103'::uuid,
            100000,
            now(),
            'completed'::public.transaction_status
        )
    $$,
    'P0001',
    'Cross-currency transfers are not supported',
    'Cross-currency transfers must be rejected'
);


-- ============================================================
-- 26. Idempotent transaction creation
-- ============================================================


-- Test 23
select is(
    (
        with first_request as (
            select public.create_transaction(
                '00000000-0000-0000-0000-000000000407'::uuid,
                '00000000-0000-0000-0000-000000000101'::uuid,
                '00000000-0000-0000-0000-000000000302'::uuid,
                'expense'::public.transaction_type,
                250000,
                'Idempotent Merchant',
                'First request',
                now(),
                'completed'::public.transaction_status
            )::text as transaction_id
        ),
        second_request as (
            select public.create_transaction(
                '00000000-0000-0000-0000-000000000407'::uuid,
                '00000000-0000-0000-0000-000000000101'::uuid,
                '00000000-0000-0000-0000-000000000302'::uuid,
                'expense'::public.transaction_type,
                250000,
                'Idempotent Merchant',
                'First request',
                now(),
                'completed'::public.transaction_status
            )::text as transaction_id
            from first_request
        )
        select transaction_id
        from second_request
    ),
    '00000000-0000-0000-0000-000000000407',
    'Retrying transaction creation returns the original transaction ID'
);


-- Test 24
select results_eq(
    $$
        select count(*)
        from public.transactions
        where id =
            '00000000-0000-0000-0000-000000000407'::uuid
    $$,
    $$values (1::bigint)$$,
    'Idempotent transaction request creates only one transaction'
);


-- Test 25
select throws_ok(
    $$
        select public.create_transaction(
            '00000000-0000-0000-0000-000000000407'::uuid,
            '00000000-0000-0000-0000-000000000101'::uuid,
            '00000000-0000-0000-0000-000000000302'::uuid,
            'expense'::public.transaction_type,
            999999,
            'Different Merchant',
            'Conflicting retry',
            now(),
            'completed'::public.transaction_status
        )
    $$,
    'P0002',
    'Transaction ID was reused with different financial data',
    'Transaction idempotency key cannot be reused for different financial data'
);


-- ============================================================
-- 27. Idempotent transfer creation
-- ============================================================


-- Test 26
select is(
    (
        with first_request as (
            select public.create_transfer(
                '00000000-0000-0000-0000-000000000503'::uuid,
                '00000000-0000-0000-0000-000000000101'::uuid,
                '00000000-0000-0000-0000-000000000102'::uuid,
                750000,
                now(),
                'completed'::public.transaction_status
            )::text as transfer_id
        ),
        second_request as (
            select public.create_transfer(
                '00000000-0000-0000-0000-000000000503'::uuid,
                '00000000-0000-0000-0000-000000000101'::uuid,
                '00000000-0000-0000-0000-000000000102'::uuid,
                750000,
                now(),
                'completed'::public.transaction_status
            )::text as transfer_id
            from first_request
        )
        select transfer_id
        from second_request
    ),
    '00000000-0000-0000-0000-000000000503',
    'Retrying transfer creation returns the original transfer ID'
);


-- Test 27
select results_eq(
    $$
        select count(*)
        from public.transfers
        where id =
            '00000000-0000-0000-0000-000000000503'::uuid
    $$,
    $$values (1::bigint)$$,
    'Idempotent transfer request creates one transfer record'
);


-- Test 28
select results_eq(
    $$
        select count(*)
        from public.transactions
        where transfer_id =
            '00000000-0000-0000-0000-000000000503'::uuid
    $$,
    $$values (2::bigint)$$,
    'A transfer creates exactly two transaction legs'
);


-- Test 29
select throws_ok(
    $$
        select public.create_transfer(
            '00000000-0000-0000-0000-000000000503'::uuid,
            '00000000-0000-0000-0000-000000000101'::uuid,
            '00000000-0000-0000-0000-000000000102'::uuid,
            999999,
            now(),
            'completed'::public.transaction_status
        )
    $$,
    'P0002',
    'Transfer ID was reused with different financial data',
    'Transfer idempotency key cannot be reused for different financial data'
);


-- ============================================================
-- 28. Atomic rollback
--
-- This is the most important test in the suite.
--
-- The transfer and both legs begin pending.
--
-- complete_transfer() changes the two legs first, then the
-- test-only trigger deliberately fails while changing the
-- transfer row.
--
-- PostgreSQL must roll back:
--
--   transaction source -> pending
--   transaction target -> pending
--   transfer            -> pending
--
-- None of the partial changes may survive.
-- ============================================================


-- Test 30
select throws_ok(
    $$
        select public.complete_transfer(
            '00000000-0000-0000-0000-000000000504'::uuid
        )
    $$,
    'P0001',
    'Intentional test failure during transfer completion',
    'Transfer completion failure rolls back the entire operation'
);


-- Test 31
select results_eq(
    $$
        select status::text
        from public.transfers
        where id =
            '00000000-0000-0000-0000-000000000504'::uuid
    $$,
    $$values ('pending')$$,
    'Atomic rollback leaves transfer pending'
);


-- Test 32
select results_eq(
    $$
        select count(*)
        from public.transactions
        where transfer_id =
            '00000000-0000-0000-0000-000000000504'::uuid
          and status = 'pending'
    $$,
    $$values (2::bigint)$$,
    'Atomic rollback leaves both transfer legs pending'
);

-- Test 33
select is(
    (
        select count(*)
        from pg_tables
        where schemaname = 'public'
          and tablename in (
              'profiles',
              'accounts',
              'categories',
              'transfers',
              'transactions',
              'budgets'
          )
          and rowsecurity = true
    ),
    6::bigint,
    'RLS is enabled on all finance tables'
);


-- ============================================================
-- Finish
-- ============================================================

select * from finish();

rollback;