-- The grants the service role relies on are explicit, and nobody else got them.
begin;
select plan(7);

select ok(has_table_privilege('service_role', 'public.admin_users', 'insert'), 'the service role can create staff rows');
select ok(has_table_privilege('service_role', 'public.admin_users', 'update'), 'and change them');
select ok(has_table_privilege('service_role', 'public.admin_users', 'delete'), 'and remove them');
select ok(not has_table_privilege('anon', 'public.admin_users', 'select'), 'a guest cannot read the staff table');
select ok(not has_table_privilege('authenticated', 'public.admin_users', 'insert'), 'a customer cannot make themselves staff');
select ok(not has_table_privilege('authenticated', 'public.admin_users', 'update'), 'or change a role');
select ok(
  has_function_privilege('service_role', 'public.apply_payment_event(text, text, uuid, text, jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'public.apply_payment_event(text, text, uuid, text, jsonb)', 'execute'),
  'only the service role reports payment events'
);

select * from finish();
rollback;
