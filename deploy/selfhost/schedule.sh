#!/usr/bin/env bash
# Schedules the jobs the database runs by itself (pg_cron, which is part of the Supabase
# Postgres image):
#
#   zaba-expire-unpaid   every 10 minutes: cancels the orders that have waited for their
#                        payment longer than ZABA_UNPAID_MINUTES (default 30, at least 5) and gives
#                        their places in the delivery slots back (public.expire_unpaid_orders)
#   zaba-cron-history    every night: forgets what pg_cron remembers about runs older than a week
#
#   deploy/selfhost/schedule.sh
#
# Safe to run again: a job with the same name is replaced, so a changed ZABA_UNPAID_MINUTES
# takes effect by running this once more. install.sh runs it. Without the expiry an order that
# is never paid keeps its place in the slot for ever (a customer can have at most five).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${ZABA_SELFHOST_ENV:-$here/zaba-selfhost.env}"
if [ -f "$config" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$config"
  set +a
fi
stack="${ZABA_STACK_DIR:-$HOME/zaba-stack}"
[ -f "$stack/.env" ] || { echo "ERROR: no stack in $stack. Run install.sh first." >&2; exit 1; }

minutes="${ZABA_UNPAID_MINUTES:-30}"
case "$minutes" in ''|*[!0-9]*) echo "ERROR: ZABA_UNPAID_MINUTES must be a whole number of minutes." >&2; exit 1 ;; esac
[ "$minutes" -ge 5 ] || { echo "ERROR: ZABA_UNPAID_MINUTES must be at least 5 (the database refuses less)." >&2; exit 1; }

cd "$stack"
# The job runs as the role that schedules it; the superuser may call the function, which only
# the service role (and nobody else) is granted.
docker compose exec -T db psql -U supabase_admin -d postgres -X -q -v ON_ERROR_STOP=1 >/dev/null <<SQL
create extension if not exists pg_cron;
select cron.schedule('zaba-expire-unpaid', '*/10 * * * *',
  \$\$select public.expire_unpaid_orders(interval '${minutes} minutes')\$\$);
select cron.schedule('zaba-cron-history', '17 3 * * *',
  \$\$delete from cron.job_run_details where end_time < now() - interval '7 days'\$\$);
SQL
echo "Scheduled: unpaid orders are cancelled after ${minutes} minutes (checked every 10 minutes)."
