select
    schemaname,
    tablename,
    rowsecurity
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
order by tablename;