-- ============================================================
-- Finance Dashboard
-- Migration: ensure_finance_rls_enabled
--
-- Purpose:
--   Explicitly enable PostgreSQL Row Level Security on every
--   finance table.
--
-- This migration is intentionally limited to the table-level
-- RLS setting.
--
-- Policies are NOT changed here.
-- Grants are NOT changed here.
-- ============================================================


-- ============================================================
-- 1. Profiles
-- ============================================================

alter table public.profiles
enable row level security;


-- ============================================================
-- 2. Accounts
-- ============================================================

alter table public.accounts
enable row level security;


-- ============================================================
-- 3. Categories
-- ============================================================

alter table public.categories
enable row level security;


-- ============================================================
-- 4. Transfers
-- ============================================================

alter table public.transfers
enable row level security;


-- ============================================================
-- 5. Transactions
-- ============================================================

alter table public.transactions
enable row level security;


-- ============================================================
-- 6. Budgets
-- ============================================================

alter table public.budgets
enable row level security;