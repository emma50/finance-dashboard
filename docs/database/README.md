# Database

This directory will contain the Supabase database migrations and seed scripts.

The first migration should establish:

- account type enum
- transaction type enum
- transaction status enum
- profiles
- accounts
- categories
- transfers
- transactions
- budgets
- structural constraints
- ownership foreign keys
- essential indexes

The next migration should establish RLS and least-privilege database access.

Seed data is deliberately kept separate from schema migrations.
