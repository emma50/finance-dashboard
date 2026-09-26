# Development Workflow

We build one logical concern at a time.

## Commit rule

Every commit should answer one engineering question.

Good:

```text
feat: add finance schema
feat: add transaction RLS policies
feat: seed deterministic transaction data
feat: add dashboard summary query
perf: cache transaction list queries
test: cover transfer invariants
```

Bad:

```text
feat: finish dashboard
```

## Required loop

```text
Understand
→ design
→ implement one logic
→ test
→ review
→ commit
```

## Definition of done for a logical unit

- TypeScript passes.
- ESLint passes.
- Relevant unit tests pass.
- Relevant UI behavior is manually inspected.
- Security boundary is considered.
- Query behavior is understood.
- Commit message describes the actual change.

## Performance rule

Do not add memoization, Web Workers, aggressive caching, or additional database indexes without a concrete workload or measurement.
