select
    p.proname,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.prosecdef as security_definer,
    pg_get_functiondef(p.oid) like '%set search_path = ''''' as search_path_is_pinned
from pg_proc p
join pg_namespace n
    on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
      'create_transaction',
      'complete_transaction',
      'cancel_transaction',
      'create_transfer',
      'complete_transfer',
      'cancel_transfer'
  )
order by p.proname;