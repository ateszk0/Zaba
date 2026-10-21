-- Which functions each role may call, as a closed list.
--
-- PostgreSQL gives every NEW function to PUBLIC (everybody, guests included), and the
-- default privileges of 20261021090700 cannot take that away: only an explicit
-- `revoke ... from public` on the function can. A function added later without that line is
-- open to guests, and nothing else would notice. This test does: it fails for any function
-- in `public` or `private` that is callable by a role and is not on the list below.
--
-- Adding a function that is meant to be callable? Add it to the list here as well.
begin;
select plan(5);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  array['quote_cart'],
  'a guest can call only quote_cart in public'
);
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')),
  array['admin_set_order_status', 'cancel_order', 'get_delivery_slots', 'place_order', 'quote_cart', 'start_payment'],
  'a signed-in customer can call exactly the customer functions in public'
);
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('service_role', p.oid, 'execute')),
  array['admin_set_order_status', 'apply_payment_event', 'cancel_order', 'expire_unpaid_orders',
        'get_delivery_slots', 'place_order', 'quote_cart', 'start_payment'],
  'the service role can call the functions above and the two that only it may call'
);
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('anon', p.oid, 'execute')),
  array['allergen_codes', 'compute_quote', 'vat_from_gross'],
  'a guest can call only the three helpers that table constraints and quote_cart need in private'
);
select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'execute')),
  array['admin_role', 'allergen_codes', 'compute_quote', 'is_staff', 'vat_from_gross'],
  'a signed-in customer adds only the two staff checks that the policies use'
);

select * from finish();
rollback;
