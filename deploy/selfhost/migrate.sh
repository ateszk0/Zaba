#!/usr/bin/env bash
# Applies supabase/migrations/*.sql to the self-hosted database: each file once,
# in order, in its own transaction. Applied versions are recorded in
# supabase_migrations.schema_migrations, the same table the Supabase CLI uses,
# so `supabase db push` would agree with this script.
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

psql_db -q -c "create schema if not exists supabase_migrations;
  create table if not exists supabase_migrations.schema_migrations (
    version text primary key, statements text[], name text);"

applied=0
for file in "$repo"/supabase/migrations/*.sql; do
  base="$(basename "$file" .sql)"
  version="${base%%_*}"
  name="${base#*_}"
  if [ -n "$(psql_db -At -c "select 1 from supabase_migrations.schema_migrations where version = '$version'")" ]; then
    echo "  already applied  $base"
    continue
  fi
  echo "  applying         $base"
  {
    echo "begin;"
    cat "$file"
    printf '\ninsert into supabase_migrations.schema_migrations (version, name, statements) values (%s, %s, %s);\n' \
      "'$version'" "'$name'" "'{}'"
    echo "commit;"
  } | psql_db -q >/dev/null
  applied=$((applied + 1))
done
echo "Migrations: $applied applied."
