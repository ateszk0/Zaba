-- Accounts: profiles, saved addresses, staff and the audit log.
-- Sign-in itself (email + password) is handled by Supabase Auth (auth.users).

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (full_name is null or length(full_name) <= 200),
  phone text check (phone is null or length(phone) <= 40),
  -- Allergens the customer wants to be warned about on the menu.
  avoid_allergens text[] not null default '{}' check (avoid_allergens <@ private.allergen_codes()),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function private.touch_updated_at();

-- Every new account gets a profile.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  label text check (label is null or length(label) <= 60),
  postal_code text not null check (postal_code ~ '^[0-9]{4}$'),
  street text not null check (length(btrim(street)) > 0 and length(street) <= 200),
  note text check (note is null or length(note) <= 300),
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create index addresses_user_idx on public.addresses (user_id);

-- A customer has at most one default address.
create unique index addresses_one_default_idx
  on public.addresses (user_id)
  where is_default;

-- Staff of the kitchen/shop. `operator` only handles orders; `admin` can do
-- everything. Rows are created by an administrator (service role), never by
-- the user.
create table public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role public.admin_role not null default 'operator',
  created_at timestamptz not null default now()
);

-- Every action a staff member takes is recorded here.
create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  entity text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_created_idx on public.audit_log (created_at desc);

-- Is the current user staff, and with which role? Used by RLS policies and the
-- admin functions.
create function private.admin_role()
returns public.admin_role
language sql
stable
security definer
set search_path = ''
as $$
  select a.role from public.admin_users a where a.user_id = auth.uid()
$$;

create function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admin_users a where a.user_id = auth.uid())
$$;

grant execute on function private.admin_role() to authenticated;
grant execute on function private.is_staff() to authenticated;
