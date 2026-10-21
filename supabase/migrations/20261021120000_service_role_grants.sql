-- What the service role may do, written down instead of inherited.
--
-- Supabase stopped granting every new public table to `anon`, `authenticated` and
-- `service_role` by default (new projects since 30 May 2026, existing ones from
-- 30 October 2026). Everything the customer and the admin pages touch is already
-- granted explicitly in 20261021090700_security_and_realtime.sql. The service role
-- calls the payment function and the staff tool uses it to create staff rows, so
-- those grants are explicit too, and a project without the old defaults behaves
-- like the local one.

grant select, insert, update, delete on public.admin_users to service_role;
