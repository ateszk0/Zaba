#!/usr/bin/env bash
# Puts the Zaba backend into a hosted Supabase project: the database schema, the
# demo menu, the payment functions and their secret. Everything comes from this
# repository (supabase/migrations, supabase/seed, supabase/functions).
#
#   export SUPABASE_ACCESS_TOKEN=...        # an account token (dashboard > Account > Access tokens)
#   export SUPABASE_PROJECT_REF=...         # the project's reference (the part before .supabase.co)
#   export SUPABASE_DB_PASSWORD=...         # the database password chosen when the project was created
#   export FAKE_PAYMENT_WEBHOOK_SECRET="$(openssl rand -hex 32)"   # keep it: the payment functions and
#                                                                  # payment_smoke.py both need it
#   deploy/demo/setup-supabase.sh first     # a new, empty project: schema + demo menu + functions
#   deploy/demo/setup-supabase.sh update    # later: new migrations and the functions again
#
# Nothing here is printed or stored: the values stay in this shell. The demo menu is
# loaded only by `first` (loading it twice would fail on the duplicate rows).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

mode="${1:-}"
case "$mode" in first|update) ;; *) echo "Usage: $0 first|update" >&2; exit 1 ;; esac
for var in SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF SUPABASE_DB_PASSWORD FAKE_PAYMENT_WEBHOOK_SECRET; do
  [ -n "${!var:-}" ] || { echo "ERROR: $var is not set (see the top of this script)." >&2; exit 1; }
done
[ "${#FAKE_PAYMENT_WEBHOOK_SECRET}" -ge 32 ] || { echo "ERROR: FAKE_PAYMENT_WEBHOOK_SECRET is too short (use openssl rand -hex 32)." >&2; exit 1; }

cd "$repo"
supabase() { npx --no-install supabase "$@"; }

echo "==> Linking the project"
supabase link --project-ref "$SUPABASE_PROJECT_REF" --password "$SUPABASE_DB_PASSWORD"

echo "==> Database: migrations$([ "$mode" = first ] && echo ' and the demo menu')"
if [ "$mode" = first ]; then
  supabase db push --linked --password "$SUPABASE_DB_PASSWORD" --include-seed
else
  supabase db push --linked --password "$SUPABASE_DB_PASSWORD"
fi

echo "==> Payment secret"
# Through a file, not the command line, so it does not show up in the process list.
secret_file="$(mktemp)"
trap 'rm -f "$secret_file"' EXIT
chmod 600 "$secret_file"
printf 'FAKE_PAYMENT_WEBHOOK_SECRET=%s\n' "$FAKE_PAYMENT_WEBHOOK_SECRET" > "$secret_file"
supabase secrets set --project-ref "$SUPABASE_PROJECT_REF" --env-file "$secret_file"

echo "==> Edge Functions"
supabase functions deploy --project-ref "$SUPABASE_PROJECT_REF" --use-api

cat <<NEXT

Done. Still to do by hand, once (Dashboard > Authentication):
  - Sign In / Providers > Email: turn "Confirm email" OFF (the demo sends no mail).
  - Sign In / Providers: "Allow new users to sign up" ON (it is by default).
  - URL Configuration: set Site URL to the address of the customer app.
Then create the demo accounts and check everything: docs/demo-environment.md.
NEXT
