-- Pricing the cart and generating delivery slots.
--
-- Errors are raised with a short code as the message (for example
-- `out_of_delivery_area`); the app maps the code to a Hungarian text.

-- Prices a cart. `p_lines` is a JSON array of {"product_id": text,
-- "quantity": int}. Without a postal code the default zone is assumed and the
-- result is flagged as estimated. Runs with the caller's rights, so it sees
-- exactly what the catalog policies show.
create function private.compute_quote(p_lines jsonb, p_postal_code text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_zone public.delivery_zones;
  v_lines jsonb;
  v_subtotal integer;
  v_fee integer;
begin
  -- 1. The cart must be a short array of {product_id, quantity 1..99}.
  begin
    if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) > 100 then
      raise exception 'invalid_lines';
    end if;
    if exists (
      select 1
        from jsonb_array_elements(p_lines) e
       where jsonb_typeof(e.value) <> 'object'
          or (e.value ->> 'product_id') is null
          or (e.value ->> 'quantity') is null
          or (e.value ->> 'quantity')::integer not between 1 and 99
    ) then
      raise exception 'invalid_lines';
    end if;
  exception when invalid_text_representation or numeric_value_out_of_range then
    -- A quantity that is not a whole number.
    raise exception 'invalid_lines';
  end;

  -- 2. The delivery zone: of the address, or the default one for an estimate.
  if p_postal_code is null then
    select z.* into v_zone from public.delivery_zones z where z.is_estimate_default;
    if not found then
      raise exception 'delivery_not_configured';
    end if;
  else
    if p_postal_code !~ '^[0-9]{4}$' then
      raise exception 'out_of_delivery_area';
    end if;
    select z.* into v_zone
      from public.delivery_zones z
      join public.delivery_zone_prefixes p on p.zone_id = z.id
     where p.prefix = left(p_postal_code, 3);
    if not found then
      raise exception 'out_of_delivery_area';
    end if;
  end if;

  -- 3. Price the lines. The same product twice is one line; unknown and
  -- inactive products are left out.
  with raw as (
    select
      e.ordinality as position,
      e.value ->> 'product_id' as product_id,
      (e.value ->> 'quantity')::integer as quantity
    from jsonb_array_elements(p_lines) with ordinality as e (value, ordinality)
  ), agg as (
    select product_id, sum(quantity)::integer as quantity, min(position) as position
      from raw
     group by product_id
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', a.product_id,
          'name', p.name,
          'quantity', a.quantity,
          'unit_price_huf', pr.amount_huf,
          'vat_rate_percent', p.vat_rate_percent,
          'line_total_huf', pr.amount_huf * a.quantity
        )
        order by a.position
      ),
      '[]'::jsonb
    ),
    coalesce(sum(pr.amount_huf::bigint * a.quantity), 0)::integer
  into v_lines, v_subtotal
  from agg a
  join public.products p on p.id = a.product_id and p.is_active
  join public.product_prices pr on pr.product_id = p.id and pr.valid_to is null;

  if exists (select 1 from jsonb_array_elements(v_lines) l where (l.value ->> 'quantity')::integer > 99) then
    raise exception 'invalid_lines';
  end if;

  v_fee := case
    when v_subtotal = 0 then 0
    when v_zone.free_delivery_from_huf is not null
         and v_subtotal >= v_zone.free_delivery_from_huf then 0
    else v_zone.delivery_fee_huf
  end;

  return jsonb_build_object(
    'lines', v_lines,
    'subtotal_huf', v_subtotal,
    'delivery_fee_huf', v_fee,
    'total_huf', v_subtotal + v_fee,
    'min_order_huf', v_zone.min_order_huf,
    'free_delivery_from_huf', v_zone.free_delivery_from_huf,
    'zone_id', v_zone.id,
    'estimated', p_postal_code is null
  );
end;
$$;

create function public.quote_cart(p_lines jsonb, p_postal_code text default null)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.compute_quote(p_lines, p_postal_code)
$$;

-- Makes sure the slot rows of the booking window exist and returns the
-- bookable ones: not earlier than the lead time, not full. Slots are laid out
-- in the time zone of the shop, so daylight saving time shifts them correctly
-- in UTC. `p_now` is a parameter so the logic can be tested at fixed times.
create function private.generate_delivery_slots(p_now timestamptz)
returns setof public.delivery_slots
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.delivery_settings;
  v_today date;
  v_day date;
  h public.opening_hours;
  v_local timestamp;
  v_step interval;
  v_horizon timestamptz;
begin
  select * into s from public.delivery_settings;
  if not found then
    raise exception 'delivery_not_configured';
  end if;

  v_step := make_interval(mins => s.slot_minutes);
  v_today := (p_now at time zone s.timezone)::date;

  for i in 0 .. s.days_ahead - 1 loop
    v_day := v_today + i;
    select * into h from public.opening_hours where weekday = extract(isodow from v_day)::integer;
    continue when not found;

    v_local := v_day + h.opens_at;
    while v_local + v_step <= v_day + h.closes_at loop
      insert into public.delivery_slots (starts_at, ends_at, capacity)
      values (v_local at time zone s.timezone, (v_local + v_step) at time zone s.timezone, s.slot_capacity)
      on conflict (starts_at, ends_at) do nothing;
      v_local := v_local + v_step;
    end loop;
  end loop;

  v_horizon := (v_today + s.days_ahead)::timestamp at time zone s.timezone;

  -- What is bookable is decided here and only here: inside the current opening
  -- hours (slot rows created earlier stay in the table when the hours change),
  -- not closer than the lead time, inside the window, not full.
  return query
    select sl.*
      from public.delivery_slots sl
      join public.opening_hours oh
        on oh.weekday = extract(isodow from (sl.starts_at at time zone s.timezone))::integer
       and (sl.starts_at at time zone s.timezone)::time >= oh.opens_at
       and (sl.ends_at at time zone s.timezone)::time <= oh.closes_at
     where sl.starts_at >= p_now + make_interval(mins => s.lead_time_minutes)
       and sl.starts_at < v_horizon
       and sl.booked < sl.capacity
     order by sl.starts_at;
end;
$$;

create function public.get_delivery_slots()
returns table (slot_id uuid, starts_at timestamptz, ends_at timestamptz, remaining integer)
language sql
security definer
set search_path = ''
as $$
  select s.id, s.starts_at, s.ends_at, s.capacity - s.booked
    from private.generate_delivery_slots(now()) s
$$;

grant execute on function private.compute_quote(jsonb, text) to anon, authenticated;
