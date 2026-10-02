-- ============================================================
-- Finance Dashboard
-- Deterministic Development Seed
--
-- Purpose:
--   Establish a small, explicit domain world that exercises
--   the invariants protected by the database test suite.
--
-- Rules:
--   - No random UUIDs.
--   - No random amounts.
--   - No now().
--   - No schema changes.
--   - Seed only known-valid domain states.
-- ============================================================


-- ============================================================
-- 1. Stable fixture identifiers
-- ============================================================
--
-- These identifiers are intentionally fixed so that developers,
-- tests, screenshots, debugging sessions, and local development
-- all refer to the same records.
--
-- ============================================================

-- Users
-- USER_A = 00000000-0000-0000-0000-000000000001
-- USER_B = 00000000-0000-0000-0000-000000000002


-- ============================================================
-- 2. Auth users
-- ============================================================
--
-- These are development fixture identities.
-- They exist so application tables can reference auth.users.
--
-- They are not intended to represent real users or production
-- credentials.
--
-- ============================================================

insert into auth.users (
    id,
    email,
    raw_user_meta_data
)
values
    (
        '00000000-0000-0000-0000-000000000001',
        'demo.user.a@finance.local',
        '{"display_name": "Demo User A"}'::jsonb
    ),
    (
        '00000000-0000-0000-0000-000000000002',
        'demo.user.b@finance.local',
        '{"display_name": "Demo User B"}'::jsonb
    );


-- ============================================================
-- 3. Profiles
-- ============================================================

insert into public.profiles (
    id,
    display_name,
    avatar_url,
    default_currency,
    timezone,
    created_at,
    updated_at
)
values
    (
        '00000000-0000-0000-0000-000000000001',
        'Demo User A',
        null,
        'NGN',
        'Africa/Lagos',
        '2026-09-01 08:00:00+00',
        '2026-09-01 08:00:00+00'
    ),
    (
        '00000000-0000-0000-0000-000000000002',
        'Demo User B',
        null,
        'NGN',
        'Africa/Lagos',
        '2026-09-01 08:05:00+00',
        '2026-09-01 08:05:00+00'
    );


-- ============================================================
-- 4. Categories
-- ============================================================
--
-- Categories are global reference data.
--
-- Transfer intentionally has no category because transfer
-- semantics are represented by the transfer record + its
-- two transaction legs.
--
-- ============================================================

insert into public.categories (
    id,
    name,
    type,
    icon,
    created_at
)
values
    -- Income categories
    (
        '10000000-0000-0000-0000-000000000001',
        'Salary',
        'income',
        'briefcase',
        '2026-09-01 09:00:00+00'
    ),
    (
        '10000000-0000-0000-0000-000000000002',
        'Freelance',
        'income',
        'laptop',
        '2026-09-01 09:01:00+00'
    ),

    -- Expense categories
    (
        '10000000-0000-0000-0000-000000000101',
        'Rent',
        'expense',
        'home',
        '2026-09-01 09:02:00+00'
    ),
    (
        '10000000-0000-0000-0000-000000000102',
        'Groceries',
        'expense',
        'shopping-cart',
        '2026-09-01 09:03:00+00'
    ),
    (
        '10000000-0000-0000-0000-000000000103',
        'Transport',
        'expense',
        'car',
        '2026-09-01 09:04:00+00'
    ),
    (
        '10000000-0000-0000-0000-000000000104',
        'Utilities',
        'expense',
        'zap',
        '2026-09-01 09:05:00+00'
    ),
    (
        '10000000-0000-0000-0000-000000000105',
        'Entertainment',
        'expense',
        'film',
        '2026-09-01 09:06:00+00'
    );