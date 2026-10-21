#!/usr/bin/env bash
# Loads supabase/seed/*.sql (the demo menu, delivery zones, opening hours) into
# the self-hosted database. Only once: if the menu already has products it does
# nothing, so running the installer again never duplicates data or overwrites
# changes made since.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
config="${ZABA_SELFHOST_ENV:-$here/zaba-selfhost.env}"
if [ -f "$config" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$config"
  set +a
fi
stack="${ZABA_STACK_DIR:-$HOME/zaba-stack}"
[ -f "$stack/.env" ] || { echo "ERROR: no stack in $stack. Run install.sh first." >&2; exit 1; }

cd "$stack"
psql_db() { docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -X "$@"; }

if [ "$(psql_db -At -c 'select count(*) from public.products')" != "0" ]; then
  echo "Seed: the menu already has products, nothing to do."
  exit 0
fi

for file in "$repo"/supabase/seed/*.sql; do
  echo "  seeding  $(basename "$file")"
  { echo "begin;"; cat "$file"; echo "commit;"; } | psql_db -q >/dev/null
done
echo "Seed: done."
