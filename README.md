# Finance Dashboard

A production-minded finance dashboard built as a one-day learning project.

The goal is not to build a miniature bank. The goal is to build a small application that gives us real problems to solve around:

- responsive UI
- authentication
- authorization
- relational data modeling
- SQL query design
- client/server state
- caching
- performance measurement
- Web Worker trade-offs
- testing
- CI

## Stack

- Next.js 16
- React 19
- TypeScript
- Tailwind CSS 4
- Supabase Auth + PostgreSQL
- `@supabase/ssr` for cookie-based SSR authentication
- TanStack Query v5
- Zod
- Vitest
- Playwright

## Project shape

```text
src/
├── app/
│   ├── (auth)/
│   ├── (dashboard)/
│   └── api/
├── components/
│   ├── layout/
│   └── ui/
├── features/
│   ├── accounts/
│   ├── analytics/
│   ├── auth/
│   ├── budgets/
│   ├── dashboard/
│   └── transactions/
├── lib/
│   ├── constants/
│   ├── env/
│   ├── formatters/
│   ├── supabase/
│   └── utils/
├── providers/
├── types/
└── workers/

supabase/
├── migrations/
└── seed/

tests/
├── e2e/
└── unit/
```

## Local setup

### 1. Install

```bash
npm install
```

The repository intentionally does not ship a generated `package-lock.json` because dependencies have not been installed in this scaffold. Once you run `npm install`, commit the generated lockfile.

### 2. Environment

```bash
cp .env.example .env.local
```

Add:

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

Never put a Supabase secret/service key in a `NEXT_PUBLIC_*` variable or browser code.

### 3. Start development

```bash
npm run dev
```

### 4. Quality checks

```bash
npm run check
```

### 5. E2E tests

```bash
npx playwright install
npm run test:e2e
```

## Important architecture notes

### Next.js 16 Proxy

Next.js 16 renamed the `middleware.ts` convention to `proxy.ts`. This project follows the current convention.

### Supabase SSR

The project uses `@supabase/ssr` with:

- browser client
- server client
- request proxy

Do not create a global server-side Supabase client.

### Authorization

The application must not depend on frontend route guards as the security boundary. PostgreSQL RLS is the authoritative row-level authorization layer.

### Finance data

Financial values are represented as integer minor units in the database.

For example:

```text
₦25,500.75 → 2,550,075 kobo
```

Current balance, spending totals, savings rate and budget utilization are derived values.

## Build order

```text
1. Schema migration
2. RLS + least-privilege access
3. Deterministic seed data
4. Auth UI + protected routes
5. Dashboard queries
6. Transactions
7. Accounts
8. Budgets
9. Analytics
10. Caching
11. Performance measurement
12. Web Worker experiment
13. Responsive/accessibility polish
```

## Commit style

Use small, reviewable commits:

```text
feat: add finance database schema
feat: add row level security policies
feat: seed deterministic finance data
feat: add authentication flow
feat: add dashboard summary query
feat: add transaction pagination
perf: cache dashboard queries
test: cover transaction lifecycle
```
