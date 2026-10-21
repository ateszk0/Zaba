#!/usr/bin/env bash
# Restores a backup made by backup.sh.
#
#   deploy/selfhost/restore.sh data <backup> [--yes]   replace the database with the backup's
#   deploy/selfhost/restore.sh env  <backup>           put the backup's secrets (.env) in place
#
# On the SAME server after data loss, run `data`. On a NEW server (or after the stack
# directory is gone) the order is: `env`, then install.sh, then `data`. Doing `env` first
# matters: install.sh generates new secrets when it finds none, and new secrets would
# invalidate the key inside the shipped apps and every session. With the old .env in place
# (and the marker file `env` creates) install.sh keeps them.
#
# `data` needs the same stack release and the same migrations as the backup (it refuses
# otherwise), stops everything except the database, replaces the data of the public, auth and
# storage schemas in ONE transaction (if anything fails the database is left as it was), and
# starts the stack again. It replaces ALL application data, so it asks first (--yes skips it).
#
#   ZABA_BACKUP_PASSPHRASE_FILE   needed for a .tar.enc backup
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

die() { echo "ERROR: $*" >&2; exit 1; }
usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

mode="${1:-}"
backup="${2:-}"
yes=""
[ "${3:-}" = "--yes" ] && yes=1
[ -n "$mode" ] && [ -n "$backup" ] || usage
[ -f "$backup" ] || die "$backup does not exist"
case "$mode" in data|env) ;; *) usage ;; esac

umask 077
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
case "$backup" in
  *.enc)
    [ -n "${ZABA_BACKUP_PASSPHRASE_FILE:-}" ] || die "this backup is encrypted: set ZABA_BACKUP_PASSPHRASE_FILE"
    openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$ZABA_BACKUP_PASSPHRASE_FILE" -in "$backup" | tar -xf - -C "$work" \
      || die "could not decrypt $backup (wrong passphrase?)"
    ;;
  *) tar -xf "$backup" -C "$work" ;;
esac
(cd "$work" && sha256sum -c --quiet SHA256SUMS) || die "the backup is damaged (a checksum does not match); nothing was changed"
echo "Backup of $(grep '^created_utc=' "$work/MANIFEST" | cut -d= -f2): $(grep -E '^(orders|users|products)=' "$work/MANIFEST" | tr '\n' ' ')"

if [ "$mode" = "env" ]; then
  mkdir -p "$stack"
  [ ! -e "$stack/.env" ] || die "$stack/.env already exists and is not overwritten. To use the backup's secrets on a stack that has others, move the old .env away first."
  cp "$work/env" "$stack/.env"
  chmod 600 "$stack/.env"
  # Tells install.sh that the secrets exist: it generates them only when this file is missing.
  touch "$stack/.zaba-secrets-generated"
  echo "Secrets restored into $stack/.env. Now run install.sh, then: $0 data $backup"
  exit 0
fi

[ -f "$stack/.env" ] || die "no stack in $stack. Restore the secrets first ('env'), then run install.sh."
cd "$stack"
docker compose ps --status running --services | grep -qx db || die "the database container is not running (start the stack: docker compose up -d)"

current="$(grep '^JWT_SECRET=' .env | cut -d= -f2-)"
saved="$(grep '^JWT_SECRET=' "$work/env" | cut -d= -f2-)"
if [ "$current" != "$saved" ]; then
  echo "WARNING: this stack's secrets are not the backup's. The data comes back, but the API keys differ:"
  echo "         the shipped apps (built with the old public key) and all sessions stop working."
  echo "         To keep the old secrets: remove this stack and use '$0 env' before install.sh."
fi

if [ -z "$yes" ]; then
  printf 'This replaces ALL data in the database of %s with the backup. Type "restore" to go on: ' "$stack"
  read -r answer
  [ "$answer" = "restore" ] || die "cancelled"
fi

saved_ref="$(grep '^supabase_selfhost=' "$work/MANIFEST" | cut -d= -f2-)"
current_ref="$(tr -d '\n' < .supabase-version 2>/dev/null || echo unknown)"
[ "$saved_ref" = "$current_ref" ] || die "the backup is from stack release '$saved_ref' but this stack is '$current_ref'. Restore into the same release (SUPABASE_SELFHOST_REF), then upgrade."
psql_db() { docker compose exec -T db psql -U supabase_admin -d postgres -At -X "$@"; }
saved_migration="$(grep '^latest_migration=' "$work/MANIFEST" | cut -d= -f2-)"
current_migration="$(psql_db -c 'select max(version) from supabase_migrations.schema_migrations')"
[ "$saved_migration" = "$current_migration" ] || die "the backup's newest migration is $saved_migration, this database's is $current_migration. The data only fits the same schema: check out the repository version the backup was made with, run install.sh, and try again."

echo "Stopping the services (the database stays up)..."
docker compose ps --services | grep -vx db | xargs docker compose stop >/dev/null

# Only the application's own data is replaced: the tables of public, auth and storage are
# emptied and refilled from the dump's data section, in ONE transaction. The schema is not
# touched (the platform's own schemas, such as realtime, and the database's structure stay
# as install.sh made them), which is why the migrations above must match. If anything fails,
# the transaction rolls back and the database is as it was.
echo "Restoring the data (one transaction; nothing changes if it fails)..."
empty_tables="do \$\$ declare t record; begin
  for t in select schemaname, tablename from pg_tables
           where schemaname in ('public', 'auth', 'storage', 'supabase_migrations') loop
    execute format('truncate table %I.%I restart identity cascade', t.schemaname, t.tablename);
  end loop;
end \$\$;"
if ! { echo "begin;"; echo "$empty_tables"
       docker compose exec -T db pg_restore -U supabase_admin --data-only --disable-triggers \
         -n public -n auth -n storage -n supabase_migrations -f - < "$work/postgres.dump"
       echo "commit;"; } \
     | docker compose exec -T db psql -U supabase_admin -d postgres -X -q -v ON_ERROR_STOP=1 >/dev/null; then
  echo "ERROR: the restore failed; the database was not changed." >&2
  docker compose up -d >/dev/null
  exit 1
fi

echo "Starting the stack..."
if [ -n "${CLOUDFLARE_TUNNEL_TOKEN:-$(grep '^CLOUDFLARE_TUNNEL_TOKEN=' .env | cut -d= -f2-)}" ]; then
  docker compose --profile tunnel up -d >/dev/null
else
  docker compose up -d >/dev/null
fi

echo "Now in the database: users=$(psql_db -c 'select count(*) from auth.users') orders=$(psql_db -c 'select count(*) from public.orders') products=$(psql_db -c 'select count(*) from public.products')"
echo "Restored. Check it: sh run.sh logs, and the smoke tests in docs/real-life-plan.md."
