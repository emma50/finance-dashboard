-- ============================================================
-- Finance Dashboard
-- Migration: add_finance_schema
--
-- Purpose:
--   Establish the foundational relational model for the
--   finance dashboard.
--
-- Included:
--   - domain enums
--   - profiles
--   - accounts
--   - categories
--   - transfers
--   - transactions
--   - budgets
--   - structural constraints
--   - ownership constraints
--   - essential query-driven indexes
--   - database-managed updated_at
--   - account-currency immutability
--   - transfer currency validation
--   - RLS enabled as a security baseline
--
-- Deliberately excluded:
--   - RLS policies
--   - seed data
--   - financial write RPCs
--   - authentication UI
--   - dashboard views
--   - caching
-- ============================================================


-- ============================================================
-- 1. Domain enums
-- ============================================================

create type public.account_type as enum (
    'current',
    'savings',
    'cash',
    'credit_card'
);

create type public.transaction_type as enum (
    'income',
    'expense',
    'transfer'
);

create type public.transaction_status as enum (
    'pending',
    'completed',
    'cancelled'
);


-- ============================================================
-- 2. Profiles
--
-- Supabase Auth owns identity through auth.users.
--
-- This table contains application-specific profile data.
--
-- profiles.id intentionally uses the same UUID as auth.users.id.
-- ============================================================

create table public.profiles (
    id uuid primary key
        references auth.users(id)
        on delete cascade,

    display_name text not null,

    avatar_url text,

    default_currency varchar(3) not null default 'NGN',

    timezone text not null default 'Africa/Lagos',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint profiles_display_name_not_empty
        check (btrim(display_name) <> ''),

    constraint profiles_currency_format
        check (default_currency ~ '^[A-Z]{3}$')
);


-- ============================================================
-- 3. Accounts
--
-- Represents where the user's money lives.
--
-- Examples:
--   GTBank Current
--   Zenith Savings
--   Cash
--   Credit Card
--
-- Monetary values are stored as integer minor units.
--
-- Example:
--   ₦25,500.50 => 2550050
--
-- opening_balance_minor may be negative because a credit
-- account may begin with an outstanding balance.
-- ============================================================

create table public.accounts (
    id uuid primary key
        default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete restrict,

    name text not null,

    type public.account_type not null,

    currency varchar(3) not null default 'NGN',

    opening_balance_minor bigint not null default 0,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint accounts_name_not_empty
        check (btrim(name) <> ''),

    constraint accounts_currency_format
        check (currency ~ '^[A-Z]{3}$'),

    /*
     * Required for composite ownership foreign keys.
     *
     * This allows child tables to reference:
     *
     *   (user_id, account_id)
     *
     * against:
     *
     *   (user_id, id)
     */
    constraint accounts_user_id_id_unique
        unique (user_id, id)
);


-- ============================================================
-- 4. Categories
--
-- Shared reference data.
--
-- Categories are deliberately flat in v1.
--
-- A category can only be:
--   income
--   expense
--
-- A category can never have type = transfer.
-- ============================================================

create table public.categories (
    id uuid primary key
        default gen_random_uuid(),

    name text not null,

    type public.transaction_type not null,

    icon text,

    created_at timestamptz not null default now(),

    constraint categories_name_not_empty
        check (btrim(name) <> ''),

    constraint categories_no_transfer_type
        check (type <> 'transfer'),

    constraint categories_name_type_unique
        unique (name, type),

    /*
     * Required for the composite transaction/category FK:
     *
     *   (category_id, transaction.type)
     *       ->
     *   (categories.id, categories.type)
     */
    constraint categories_id_type_unique
        unique (id, type)
);


-- ============================================================
-- 5. Transfers
--
-- Represents one financial operation:
--
--   Account A -> Account B
--
-- A transfer will later produce exactly two transaction legs:
--
--   source      -> negative effect
--   destination -> positive effect
--
-- The creation of the transfer + two legs will be handled
-- atomically in a separate financial-write operation.
-- ============================================================

create table public.transfers (
    id uuid primary key
        default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete restrict,

    from_account_id uuid not null,

    to_account_id uuid not null,

    amount_minor bigint not null,

    status public.transaction_status not null default 'pending',

    occurred_at timestamptz not null default now(),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint transfers_amount_positive
        check (amount_minor > 0),

    constraint transfers_accounts_must_differ
        check (from_account_id <> to_account_id),

    /*
     * Both source and destination accounts must belong to
     * the same user who owns the transfer.
     */
    constraint transfers_from_account_owner_fk
        foreign key (user_id, from_account_id)
        references public.accounts (user_id, id)
        on delete restrict,

    constraint transfers_to_account_owner_fk
        foreign key (user_id, to_account_id)
        references public.accounts (user_id, id)
        on delete restrict,

    /*
     * Required for transactions.transfer_id ownership checks.
     */
    constraint transfers_user_id_id_unique
        unique (user_id, id)
);


-- ============================================================
-- 6. Transactions
--
-- Central financial-event table.
--
-- Amount is ALWAYS positive.
--
-- Direction/meaning is represented by type:
--
--   income
--   expense
--   transfer
--
-- Relationship rules:
--
--   income
--     category required
--     transfer forbidden
--
--   expense
--     category required
--     transfer forbidden
--
--   transfer
--     category forbidden
--     transfer required
-- ============================================================

create table public.transactions (
    id uuid primary key
        default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete restrict,

    account_id uuid not null,

    category_id uuid,

    transfer_id uuid,

    type public.transaction_type not null,

    status public.transaction_status not null default 'pending',

    amount_minor bigint not null,

    merchant text,

    description text,

    occurred_at timestamptz not null default now(),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint transactions_amount_positive
        check (amount_minor > 0),

    /*
     * Enforce the allowed structural shape of a transaction.
     */
    constraint transactions_type_relationship_check
        check (
            (
                type = 'income'
                and category_id is not null
                and transfer_id is null
            )
            or
            (
                type = 'expense'
                and category_id is not null
                and transfer_id is null
            )
            or
            (
                type = 'transfer'
                and category_id is null
                and transfer_id is not null
            )
        ),

    /*
     * A transaction can only reference an account belonging
     * to the same user.
     */
    constraint transactions_account_owner_fk
        foreign key (user_id, account_id)
        references public.accounts (user_id, id)
        on delete restrict,

    /*
     * The transaction's type must match the category type.
     *
     * expense + expense category -> valid
     * income + income category   -> valid
     *
     * expense + income category  -> rejected
     */
    constraint transactions_category_type_fk
        foreign key (category_id, type)
        references public.categories (id, type)
        on delete restrict,

    /*
     * A transaction may only reference a transfer owned by
     * the same user.
     */
    constraint transactions_transfer_owner_fk
        foreign key (user_id, transfer_id)
        references public.transfers (user_id, id)
        on delete restrict
);


-- ============================================================
-- 7. Budgets
--
-- v1 supports monthly budgets only.
--
-- The month column always represents the first day of the
-- corresponding month.
--
-- Example:
--
--   2026-09-01 => September 2026
-- ============================================================

create table public.budgets (
    id uuid primary key
        default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete restrict,

    category_id uuid not null
        references public.categories(id)
        on delete restrict,

    month date not null,

    amount_minor bigint not null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint budgets_amount_positive
        check (amount_minor > 0),

    constraint budgets_month_must_be_first_day
        check (extract(day from month) = 1),

    /*
     * One budget per user/category/month.
     */
    constraint budgets_user_category_month_unique
        unique (user_id, category_id, month)
);


-- ============================================================
-- 8. updated_at maintenance
--
-- The database owns updated_at.
--
-- Application code does not need to remember to modify it on
-- every UPDATE operation.
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.updated_at = now();

    return new;
end;
$$;


create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();


create trigger accounts_set_updated_at
before update on public.accounts
for each row
execute function public.set_updated_at();


create trigger transfers_set_updated_at
before update on public.transfers
for each row
execute function public.set_updated_at();


create trigger transactions_set_updated_at
before update on public.transactions
for each row
execute function public.set_updated_at();


create trigger budgets_set_updated_at
before update on public.budgets
for each row
execute function public.set_updated_at();


-- ============================================================
-- 9. Account currency immutability
--
-- Currency is part of the account's financial identity.
--
-- We intentionally prevent changing it after account creation
-- because historical transactions derive their currency from
-- their account.
-- ============================================================

create or replace function public.prevent_account_currency_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if new.currency is distinct from old.currency then
        raise exception
            'Account currency cannot be changed after account creation';
    end if;

    return new;
end;
$$;


create trigger accounts_prevent_currency_change
before update of currency on public.accounts
for each row
execute function public.prevent_account_currency_change();


-- ============================================================
-- 10. Transfer currency validation
--
-- v1 does not support foreign-exchange transfers.
--
-- Therefore:
--
--   source account currency
--       =
--   destination account currency
--
-- This is checked whenever the transfer's account references
-- or ownership changes.
-- ============================================================

create or replace function public.validate_transfer_accounts()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    source_currency varchar(3);
    destination_currency varchar(3);
begin
    select
        source_account.currency,
        destination_account.currency
    into
        source_currency,
        destination_currency
    from public.accounts as source_account
    join public.accounts as destination_account
        on destination_account.user_id = source_account.user_id
       and destination_account.id = new.to_account_id
    where source_account.user_id = new.user_id
      and source_account.id = new.from_account_id;

    if source_currency is null
       or destination_currency is null then
        raise exception
            'Transfer source and destination accounts must exist and belong to the transfer owner';
    end if;

    if source_currency <> destination_currency then
        raise exception
            'Cross-currency transfers are not supported';
    end if;

    return new;
end;
$$;


create trigger transfers_validate_accounts
before insert or update of user_id, from_account_id, to_account_id
on public.transfers
for each row
execute function public.validate_transfer_accounts();


-- ============================================================
-- 11. Function execution privileges
--
-- These functions exist for internal trigger execution.
-- They are not application RPC endpoints.
--
-- Remove unnecessary direct execute privileges from PUBLIC.
-- ============================================================

revoke execute
on function public.set_updated_at()
from public;

revoke execute
on function public.prevent_account_currency_change()
from public;

revoke execute
on function public.validate_transfer_accounts()
from public;


-- ============================================================
-- 12. Query-driven indexes
--
-- These indexes follow the application query shapes we already
-- validated.
--
-- We deliberately avoid indexing every column.
-- ============================================================

create index transactions_user_occurred_at_idx
on public.transactions (user_id, occurred_at desc);


create index transactions_user_type_occurred_at_idx
on public.transactions (user_id, type, occurred_at desc);


create index transactions_user_account_occurred_at_idx
on public.transactions (user_id, account_id, occurred_at desc);


create index transactions_user_category_occurred_at_idx
on public.transactions (user_id, category_id, occurred_at desc);


create index transactions_user_transfer_idx
on public.transactions (user_id, transfer_id);


create index transfers_user_occurred_at_idx
on public.transfers (user_id, occurred_at desc);


create index budgets_user_month_idx
on public.budgets (user_id, month desc);


-- ============================================================
-- 13. Security baseline
--
-- Enable RLS immediately so creating this schema never creates
-- an accidental unauthorised Data API window.
--
-- Policies will be added in the NEXT logical migration.
-- ============================================================

alter table public.profiles enable row level security;

alter table public.accounts enable row level security;

alter table public.categories enable row level security;

alter table public.transfers enable row level security;

alter table public.transactions enable row level security;

alter table public.budgets enable row level security;