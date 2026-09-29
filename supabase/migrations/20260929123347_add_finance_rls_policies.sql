-- ============================================================
-- Finance Dashboard
-- Migration: add_finance_rls_policies
--
-- Purpose:
--   Establish the authorization boundary for the finance domain.
--
-- Security model:
--
--   GRANTS
--     Define which operations the authenticated client may invoke.
--
--   RLS
--     Restricts those operations to rows owned by auth.uid().
--
--   DATABASE CONSTRAINTS
--     Protect relational/domain integrity.
--
-- Deliberately excluded:
--   - financial write RPCs
--   - transaction lifecycle functions
--   - transfer creation functions
--   - service/admin authorization
-- ============================================================


-- ============================================================
-- 1. Schema access
--
-- The authenticated role needs schema usage in order to access
-- explicitly granted objects in the public schema.
-- ============================================================

grant usage on schema public to authenticated;


-- ============================================================
-- 2. Remove direct table privileges from anonymous clients
--
-- The finance application requires authentication before any
-- financial data is available.
--
-- We intentionally do not grant anon access to these tables.
-- ============================================================

revoke all on table
    public.profiles,
    public.accounts,
    public.categories,
    public.transfers,
    public.transactions,
    public.budgets
from anon;


-- ============================================================
-- 3. Remove direct table privileges from authenticated clients
--
-- We start from zero and explicitly grant only the operations
-- required by the application.
-- ============================================================

revoke all on table
    public.profiles,
    public.accounts,
    public.categories,
    public.transfers,
    public.transactions,
    public.budgets
from authenticated;


-- ============================================================
-- 4. Profiles
--
-- Browser permissions:
--
--   SELECT  -> own profile
--   INSERT  -> own profile
--   UPDATE  -> own profile
--
-- DELETE is intentionally not exposed.
-- ============================================================

grant select, insert, update
on public.profiles
to authenticated;


create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (
    (select auth.uid()) = id
);


create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (
    (select auth.uid()) = id
);


create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (
    (select auth.uid()) = id
)
with check (
    (select auth.uid()) = id
);


-- ============================================================
-- 5. Accounts
--
-- Browser permissions:
--
--   SELECT  -> own accounts
--   INSERT  -> own accounts
--   UPDATE  -> own accounts
--
-- DELETE is intentionally unavailable because accounts may have
-- historical financial transactions.
-- ============================================================

grant select, insert, update
on public.accounts
to authenticated;


create policy "accounts_select_own"
on public.accounts
for select
to authenticated
using (
    (select auth.uid()) = user_id
);


create policy "accounts_insert_own"
on public.accounts
for insert
to authenticated
with check (
    (select auth.uid()) = user_id
);


create policy "accounts_update_own"
on public.accounts
for update
to authenticated
using (
    (select auth.uid()) = user_id
)
with check (
    (select auth.uid()) = user_id
);


-- ============================================================
-- 6. Categories
--
-- Categories are shared reference data.
--
-- Authenticated users can read them.
--
-- Clients cannot insert/update/delete categories.
--
-- Category management will belong to trusted server/admin
-- operations in a future feature.
-- ============================================================

grant select
on public.categories
to authenticated;


create policy "categories_select_authenticated"
on public.categories
for select
to authenticated
using (
    true
);


-- ============================================================
-- 7. Transactions
--
-- READ ONLY from the browser.
--
-- This is intentional.
--
-- Transaction creation/update/cancellation will eventually go
-- through controlled financial write operations so that we can
-- enforce:
--
--   - lifecycle transitions
--   - completed transaction protection
--   - category compatibility
--   - ownership
--   - financial correction rules
--
-- Browser:
--
--   SELECT -> own transactions
--
-- Browser INSERT/UPDATE/DELETE:
--   denied by privilege AND by absence of policies.
-- ============================================================

grant select
on public.transactions
to authenticated;


create policy "transactions_select_own"
on public.transactions
for select
to authenticated
using (
    (select auth.uid()) = user_id
);


-- ============================================================
-- 8. Transfers
--
-- READ ONLY from the browser.
--
-- A transfer is a financial operation that creates multiple
-- related records and therefore must not be assembled through
-- arbitrary client-side CRUD.
--
-- Browser:
--
--   SELECT -> own transfers
--
-- Browser INSERT/UPDATE/DELETE:
--   denied.
-- ============================================================

grant select
on public.transfers
to authenticated;


create policy "transfers_select_own"
on public.transfers
for select
to authenticated
using (
    (select auth.uid()) = user_id
);


-- ============================================================
-- 9. Budgets
--
-- Browser permissions:
--
--   SELECT  -> own budgets
--   INSERT  -> own budgets
--   UPDATE  -> own budgets
--   DELETE  -> own budgets
--
-- Budgets are configuration/plan data rather than immutable
-- financial history, so deletion is acceptable.
--
-- The database schema separately enforces:
--
--   amount > 0
--   month is first day of month
--   one budget per category/month/user
-- ============================================================

grant select, insert, update, delete
on public.budgets
to authenticated;


create policy "budgets_select_own"
on public.budgets
for select
to authenticated
using (
    (select auth.uid()) = user_id
);


create policy "budgets_insert_own"
on public.budgets
for insert
to authenticated
with check (
    (select auth.uid()) = user_id
);


create policy "budgets_update_own"
on public.budgets
for update
to authenticated
using (
    (select auth.uid()) = user_id
)
with check (
    (select auth.uid()) = user_id
);


create policy "budgets_delete_own"
on public.budgets
for delete
to authenticated
using (
    (select auth.uid()) = user_id
);