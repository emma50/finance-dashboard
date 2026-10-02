select
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n
    on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
      'profiles',
      'accounts',
      'categories',
      'transfers',
      'transactions',
      'budgets'
  )
order by c.relname;