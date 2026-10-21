-- What a new account gets: a profile, whatever the app sent as the name.
begin;
select plan(5);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'named@example.test', '{"full_name": "  Kovács Anna "}'),
  ('00000000-0000-4000-8000-0000000000a2', 'blank@example.test', '{"full_name": "   "}'),
  ('00000000-0000-4000-8000-0000000000a3', 'nometa@example.test', '{}'),
  ('00000000-0000-4000-8000-0000000000a4', 'long@example.test', jsonb_build_object('full_name', repeat('x', 300)));

select is(
  (select full_name from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'Kovács Anna',
  'the profile takes the name from the sign-up data, trimmed'
);
select is(
  (select full_name from public.profiles where id = '00000000-0000-4000-8000-0000000000a2'),
  null,
  'a blank name is no name'
);
select is(
  (select count(*) from public.profiles where id = '00000000-0000-4000-8000-0000000000a3'),
  1::bigint,
  'an account without a name still gets a profile'
);
select is(
  (select full_name from public.profiles where id = '00000000-0000-4000-8000-0000000000a3'),
  null,
  'and its name is empty'
);
select is(
  (select length(full_name) from public.profiles where id = '00000000-0000-4000-8000-0000000000a4'),
  200,
  'a name that is too long is cut, it does not break the sign-up'
);

select * from finish();
rollback;
