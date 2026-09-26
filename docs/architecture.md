# Architecture

## Principles

This project follows a few deliberate boundaries:

1. **Next.js App Router** is the application shell and rendering framework.
2. **Supabase Auth + PostgreSQL** are the identity and persistence layers.
3. **RLS** is the database authorization boundary for user-owned data.
4. **TanStack Query** owns client-side server state and caching where client caching is justified.
5. **Server Components** are preferred for server-only data work when a client boundary is not required.
6. **Client Components** are introduced only when interactivity/browser APIs require them.
7. **Derived financial metrics** are computed from source-of-truth records rather than stored redundantly.
8. **Web Workers** are introduced only after measuring a real CPU-bound browser workload.
9. **Feature folders** own domain-specific code; shared code belongs in `components`, `lib`, `providers`, or `types`.
10. **Database types are generated**, not manually copied.

## Planned domain modules

- auth
- dashboard
- transactions
- accounts
- budgets
- analytics

## Request/data flow

```text
UI
  ↓
feature query / mutation
  ↓
Supabase client
  ↓
Postgres + RLS
  ↓
typed domain data
  ↓
UI
```

For expensive analytical workloads:

```text
transactions
  ↓
measurement
  ↓
main-thread aggregation OR Web Worker
  ↓
chart-ready data
```
