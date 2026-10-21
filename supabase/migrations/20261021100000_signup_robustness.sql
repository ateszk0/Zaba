-- Sign-up must never fail because of what the app sent as the name: a name that
-- is longer than the profile column allows is cut instead of making the whole
-- sign-up fail with a database error. (The app limits the field as well.)

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, left(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 200));
  return new;
end;
$$;
