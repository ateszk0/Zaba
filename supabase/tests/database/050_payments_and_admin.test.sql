-- Payment events, the order state machine as an operator sees it, refunds and
-- the audit log.
begin;
select plan(34);

create function pg_temp.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

create function pg_temp.act_as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  set local role service_role;
end $$;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000000000a', 'a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'b@example.test'),
  ('00000000-0000-4000-8000-00000000000c', 'operator@example.test'),
  ('00000000-0000-4000-8000-00000000000d', 'admin@example.test');
insert into public.admin_users (user_id, role) values
  ('00000000-0000-4000-8000-00000000000c', 'operator'),
  ('00000000-0000-4000-8000-00000000000d', 'admin');

create temp table o (name text primary key, id uuid);
grant all on o to authenticated, service_role;

-- --- setup: customer A places seven orders (2 carbonaras to district V = 6 570 Ft)
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
insert into o (name, id)
select n, (public.place_order('key-' || n, '[{"product_id":"carbonara","quantity":2}]', '1051', 'Váci utca 12.',
           (select slot_id from public.get_delivery_slots() order by starts_at limit 1)) ->> 'id')::uuid
  from unnest(array['paid', 'retry', 'abandoned', 'late', 'refund', 'unpaid', 'started']) n;

-- --- payment attempts ------------------------------------------------------
create temp table attempt (name text primary key, payment_id uuid);
grant all on attempt to authenticated, service_role;
insert into attempt select 'paid', (public.start_payment((select id from o where name = 'paid')) ->> 'payment_id')::uuid;

select is(
  (public.start_payment((select id from o where name = 'paid')) ->> 'amount_huf')::integer,
  6570,
  'a payment attempt is for the total of the order'
);
select is(
  (public.start_payment((select id from o where name = 'paid')) ->> 'payment_id')::uuid,
  (select payment_id from attempt where name = 'paid'),
  'asking again returns the same open attempt'
);
reset role;
select is(
  (select count(*)::integer from public.payments where order_id = (select id from o where name = 'paid')),
  1,
  'so there is still only one attempt'
);
select pg_temp.act_as('00000000-0000-4000-8000-00000000000b');
select throws_ok(
  $$select public.start_payment((select id from o where name = 'paid'))$$,
  'P0001', 'order_not_found', 'another customer cannot start a payment for the order'
);

-- --- a successful payment --------------------------------------------------
reset role;
select pg_temp.act_as_service();
select is(
  public.apply_payment_event('fake', 'evt-paid-1', (select id from o where name = 'paid'), 'succeeded'),
  '{"applied": true}'::jsonb,
  'a success event is applied'
);
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'paid')),
  row('received', 'succeeded')::text,
  'the order is now received and paid'
);
select is(
  (select status::text from public.payments where order_id = (select id from o where name = 'paid')),
  'succeeded',
  'the payment attempt succeeded'
);
select is(
  (select count(*)::integer from public.order_status_history
    where order_id = (select id from o where name = 'paid')
      and from_status = 'pending_payment' and to_status = 'received' and actor = 'payment'),
  1,
  'the history shows the payment as the actor'
);

-- --- the same event twice --------------------------------------------------
select pg_temp.act_as_service();
select is(
  public.apply_payment_event('fake', 'evt-paid-1', (select id from o where name = 'paid'), 'succeeded'),
  '{"applied": false, "reason": "duplicate"}'::jsonb,
  'the same event delivered twice is recognised'
);
reset role;
select is(
  (select count(*)::integer from public.payment_events where provider_event_id = 'evt-paid-1'),
  1,
  'and recorded once'
);

-- --- a declined card, then a retry -----------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
insert into attempt select 'retry-1', (public.start_payment((select id from o where name = 'retry')) ->> 'payment_id')::uuid;
reset role;
select pg_temp.act_as_service();
select public.apply_payment_event('fake', 'evt-retry-1', (select id from o where name = 'retry'), 'failed');
reset role;
select is(
  (select row(o.status, o.payment_status, p.status)::text
     from public.orders o join public.payments p on p.order_id = o.id
    where o.id = (select id from o where name = 'retry')),
  row('pending_payment', 'failed', 'failed')::text,
  'a declined card leaves the order waiting and the attempt failed'
);
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
insert into attempt select 'retry-2', (public.start_payment((select id from o where name = 'retry')) ->> 'payment_id')::uuid;
select isnt(
  (select payment_id from attempt where name = 'retry-2'),
  (select payment_id from attempt where name = 'retry-1'),
  'after a failure the customer gets a new attempt'
);
reset role;
select is(
  (select payment_status::text from public.orders where id = (select id from o where name = 'retry')),
  'pending',
  'and the order shows the payment as pending again'
);
select pg_temp.act_as_service();
select public.apply_payment_event('fake', 'evt-retry-2', (select id from o where name = 'retry'), 'succeeded');
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'retry')),
  row('received', 'succeeded')::text,
  'the retry can succeed'
);

-- --- an abandoned payment --------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select public.start_payment((select id from o where name = 'abandoned'));
reset role;
select pg_temp.act_as_service();
select public.apply_payment_event('fake', 'evt-abandoned-1', (select id from o where name = 'abandoned'), 'cancelled');
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'abandoned')),
  row('pending_payment', 'cancelled')::text,
  'an abandoned payment keeps the order waiting'
);

-- --- late and odd events ---------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select public.cancel_order((select id from o where name = 'late'));
reset role;
select pg_temp.act_as_service();
select is(
  public.apply_payment_event('fake', 'evt-late-1', (select id from o where name = 'late'), 'succeeded'),
  '{"applied": false, "reason": "order_not_pending"}'::jsonb,
  'a success for an order cancelled meanwhile is not applied'
);
select is(
  public.apply_payment_event('fake', 'evt-ghost-1', gen_random_uuid(), 'succeeded'),
  '{"applied": false, "reason": "unknown_order"}'::jsonb,
  'an event for an unknown order is recorded but changes nothing'
);
select throws_ok(
  $$select public.apply_payment_event('fake', 'evt-bad-1', (select id from o where name = 'paid'), 'exploded')$$,
  'P0001', 'invalid_event', 'an unknown event type is rejected'
);
reset role;
select is(
  (select row(status, payment_status)::text from public.orders where id = (select id from o where name = 'late')),
  row('cancelled', 'pending')::text,
  'the cancelled order was left alone'
);
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select throws_ok(
  $$select public.start_payment((select id from o where name = 'paid'))$$,
  'P0001', 'order_not_payable', 'an order that is already paid cannot be paid again'
);

-- --- who may move orders ---------------------------------------------------
select throws_ok(
  $$select public.admin_set_order_status((select id from o where name = 'paid'), 'preparing')$$,
  '42501', 'forbidden', 'a customer cannot move an order along'
);
select is(
  (select count(*)::integer from public.admin_users),
  0,
  'a customer sees no staff'
);

reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000c');
select is((select count(*)::integer from public.orders), 7, 'an operator sees every order');
select throws_ok(
  $$insert into public.admin_users (user_id, role) values ('00000000-0000-4000-8000-00000000000a', 'admin')$$,
  '42501', null, 'an operator cannot make anybody staff'
);
select throws_ok(
  $$select public.admin_set_order_status((select id from o where name = 'unpaid'), 'received')$$,
  'P0001', 'invalid_transition', 'an unpaid order cannot be marked as received by hand'
);

-- The happy path, one step at a time.
select public.admin_set_order_status((select id from o where name = 'paid'), 'preparing');
select throws_ok(
  $$select public.admin_set_order_status((select id from o where name = 'paid'), 'delivered')$$,
  'P0001', 'invalid_transition', 'a step cannot be skipped'
);
select public.admin_set_order_status((select id from o where name = 'paid'), 'out_for_delivery');
select public.admin_set_order_status((select id from o where name = 'paid'), 'delivered');
reset role;
select is(
  (select row(o.status, d.dispatched_at is not null, d.delivered_at is not null)::text
     from public.orders o join public.deliveries d on d.order_id = o.id
    where o.id = (select id from o where name = 'paid')),
  row('delivered', true, true)::text,
  'the order is delivered and the delivery has its times'
);
select is(
  (select count(*)::integer from public.order_status_history where order_id = (select id from o where name = 'paid')),
  5,
  'every step is in the history'
);

-- --- cancelling and refunds ------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select public.start_payment((select id from o where name = 'refund'));
select public.start_payment((select id from o where name = 'started'));
reset role;
select pg_temp.act_as_service();
select public.apply_payment_event('fake', 'evt-refund-1', (select id from o where name = 'refund'), 'succeeded');
select public.apply_payment_event('fake', 'evt-started-1', (select id from o where name = 'started'), 'succeeded');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select public.cancel_order((select id from o where name = 'refund'));
reset role;
select is(
  (select row(o.status, o.payment_status, p.status)::text
     from public.orders o join public.payments p on p.order_id = o.id
    where o.id = (select id from o where name = 'refund')),
  row('cancelled', 'refunded', 'refunded')::text,
  'a paid order cancelled by the customer is refunded'
);

select pg_temp.act_as('00000000-0000-4000-8000-00000000000c');
select public.admin_set_order_status((select id from o where name = 'started'), 'preparing');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select throws_ok(
  $$select public.cancel_order((select id from o where name = 'started'))$$,
  'P0001', 'invalid_transition', 'the customer cannot cancel once the kitchen has started'
);
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000c');
select public.admin_set_order_status((select id from o where name = 'started'), 'cancelled');
reset role;
select is(
  (select payment_status::text from public.orders where id = (select id from o where name = 'started')),
  'refunded',
  'an operator can cancel an order in preparation, and it is refunded'
);

-- --- the audit log ---------------------------------------------------------
select is(
  (select count(*)::integer from public.audit_log
    where action = 'order.set_status' and actor_id = '00000000-0000-4000-8000-00000000000c'),
  5,
  'every successful staff action is in the audit log (the rejected ones are not)'
);
select pg_temp.act_as('00000000-0000-4000-8000-00000000000c');
select is((select count(*)::integer from public.audit_log), 0, 'an operator cannot read the audit log');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-00000000000d');
select is((select count(*)::integer from public.audit_log), 5, 'an administrator can');

select * from finish();
rollback;
