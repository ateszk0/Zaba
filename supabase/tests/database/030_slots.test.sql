-- Delivery slots: opening hours, lead time, capacity, daylight saving time.
begin;
select plan(13);

create function pg_temp.act_as(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

insert into auth.users (id, email) values ('00000000-0000-4000-8000-00000000000a', 'a@example.test');

-- --- the lead time ---------------------------------------------------------
-- Wednesday 2026-10-21, 10:00 in Budapest (CEST, UTC+2) = 08:00 UTC.
select is(
  (select min(starts_at) from private.generate_delivery_slots('2026-10-21 08:00:00+00')),
  '2026-10-21 09:00:00+00'::timestamptz,
  'at 10:00 the first slot is 11:00 local (09:00 UTC): 10:45 is the earliest start'
);
select is(
  (select min(starts_at) from private.generate_delivery_slots('2026-10-21 09:16:00+00')),
  '2026-10-21 11:00:00+00'::timestamptz,
  'at 11:16 local the 12:00 slot is gone (less than 45 minutes ahead); 13:00 local is next'
);

-- --- the window ------------------------------------------------------------
-- Saturday 08:00 local. Three days: Sat 10 slots, Sun 9 (closes 20:00), Mon 10.
select is(
  (select count(*)::integer from private.generate_delivery_slots('2026-10-24 06:00:00+00')),
  29,
  'three days: Saturday 10, Sunday 9, Monday 10 slots'
);

-- --- daylight saving time --------------------------------------------------
-- 2026-10-25: clocks go back, CEST (UTC+2) becomes CET (UTC+1).
select is(
  (select min(starts_at) from private.generate_delivery_slots('2026-10-24 06:00:00+00')
    where starts_at >= '2026-10-25 00:00:00+00'),
  '2026-10-25 10:00:00+00'::timestamptz,
  'autumn: 11:00 local on Sunday is 10:00 UTC (it is 09:00 UTC on Saturday)'
);
select is(
  (select min(starts_at) from private.generate_delivery_slots('2026-10-24 06:00:00+00')),
  '2026-10-24 09:00:00+00'::timestamptz,
  'autumn: 11:00 local on Saturday is 09:00 UTC'
);
-- 2027-03-28: clocks go forward, CET (UTC+1) becomes CEST (UTC+2).
select is(
  (select min(starts_at) from private.generate_delivery_slots('2027-03-27 06:00:00+00')),
  '2027-03-27 10:00:00+00'::timestamptz,
  'spring: 11:00 local on Saturday is 10:00 UTC'
);
select is(
  (select min(starts_at) from private.generate_delivery_slots('2027-03-27 06:00:00+00')
    where starts_at >= '2027-03-28 00:00:00+00'),
  '2027-03-28 09:00:00+00'::timestamptz,
  'spring: 11:00 local on Sunday is 09:00 UTC'
);

-- --- behaviour -------------------------------------------------------------
select is(
  (select count(*)::integer from private.generate_delivery_slots('2026-10-24 06:00:00+00')),
  (select count(*)::integer from private.generate_delivery_slots('2026-10-24 06:00:00+00')),
  'asking twice gives the same slots'
);
select is(
  (select count(*)::integer from public.delivery_slots where starts_at >= '2026-10-24 00:00:00+00' and starts_at < '2026-10-27 00:00:00+00'),
  29,
  'asking again does not create duplicate rows'
);

update public.delivery_slots set booked = capacity where starts_at = '2026-10-24 09:00:00+00';
select is(
  (select min(starts_at) from private.generate_delivery_slots('2026-10-24 06:00:00+00')),
  '2026-10-24 10:00:00+00'::timestamptz,
  'a full slot is not offered'
);

delete from public.opening_hours where weekday = 7;
select is(
  (select count(*)::integer from private.generate_delivery_slots('2026-10-24 06:00:00+00')
    where starts_at >= '2026-10-25 00:00:00+00' and starts_at < '2026-10-26 00:00:00+00'),
  0,
  'a weekday without opening hours has no slots'
);

-- --- through the API -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-8000-00000000000a');
select cmp_ok(
  (select count(*)::integer from public.get_delivery_slots()), '>', 0,
  'a signed-in customer gets bookable slots'
);
select is(
  (select min(remaining) from public.get_delivery_slots()),
  10,
  'every slot starts with the configured capacity of 10'
);

select * from finish();
rollback;
