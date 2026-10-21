#!/usr/bin/env bash
# Backs up the self-hosted stack: the whole database (pg_dump, custom format) and the
# stack's secrets (its .env). Both are needed: the database holds the data, and the
# secrets (JWT secret, API keys) are what the apps built with the public key and every
# signed-in session depend on. A database dump without them restores the data but
# invalidates the key inside the shipped apps.
#
#   deploy/selfhost/backup.sh [directory]
#
#   directory                      where the backup goes (default: $ZABA_BACKUP_DIR, else ~/zaba-backups)
#   ZABA_BACKUP_PASSPHRASE_FILE    a file holding a passphrase: the backup is then encrypted
#                                  (openssl aes-256-cbc, PBKDF2) and ends in .tar.enc. Without it
#                                  the backup is a plain .tar that contains the secrets: keep it
#                                  only on an encrypted disk, and never copy it off the machine.
#   ZABA_BACKUP_KEEP               how many of the newest backups to keep (default 14)
#
# Writes zaba-<UTC time>.tar[.enc], checks that it can be read back, then prunes old ones.
# Run it from cron or a systemd timer (docs/real-life-plan.md has an example), and keep a
# copy somewhere else: a backup on the same disk does not survive the disk.
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
target="${1:-${ZABA_BACKUP_DIR:-$HOME/zaba-backups}}"
keep="${ZABA_BACKUP_KEEP:-14}"

die() { echo "ERROR: $*" >&2; exit 1; }
[ -f "$stack/.env" ] || die "no stack in $stack. Run install.sh first."
case "$keep" in ''|*[!0-9]*) die "ZABA_BACKUP_KEEP must be a number" ;; esac
if [ -n "${ZABA_BACKUP_PASSPHRASE_FILE:-}" ]; then
  [ -s "$ZABA_BACKUP_PASSPHRASE_FILE" ] || die "$ZABA_BACKUP_PASSPHRASE_FILE is missing or empty"
  command -v openssl >/dev/null || die "openssl is not installed"
fi

umask 077
mkdir -p "$target"
chmod 700 "$target"
cd "$stack"
docker compose ps --status running --services | grep -qx db || die "the database container is not running"
psql_db() { docker compose exec -T db psql -U supabase_admin -d postgres -At -X "$@"; }

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
work="$(mktemp -d "$target/.work.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# supabase_admin, not postgres: it owns the objects of the platform's own schemas, so the
# dump has all of them with their owners and grants.
docker compose exec -T db pg_dump -U supabase_admin -Fc postgres > "$work/postgres.dump"
entries="$(docker compose exec -T db pg_restore -l < "$work/postgres.dump" | grep -c '^[0-9]' || true)"
[ "$entries" -gt 100 ] || die "the dump has only $entries entries; something is wrong, nothing was kept"

cp .env "$work/env"
{
  echo "created_utc=$stamp"
  echo "supabase_selfhost=$(tr -d '\n' < .supabase-version 2>/dev/null || echo unknown)"
  echo "dump_entries=$entries"
  echo "migrations=$(psql_db -c 'select count(*) from supabase_migrations.schema_migrations')"
  echo "latest_migration=$(psql_db -c 'select max(version) from supabase_migrations.schema_migrations')"
  echo "users=$(psql_db -c 'select count(*) from auth.users')"
  echo "orders=$(psql_db -c 'select count(*) from public.orders')"
  echo "products=$(psql_db -c 'select count(*) from public.products')"
} > "$work/MANIFEST"
(cd "$work" && sha256sum postgres.dump env MANIFEST > SHA256SUMS)

partial="$target/.zaba-$stamp.partial"
tar -C "$work" -cf "$partial" .
if [ -n "${ZABA_BACKUP_PASSPHRASE_FILE:-}" ]; then
  final="$target/zaba-$stamp.tar.enc"
  openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$ZABA_BACKUP_PASSPHRASE_FILE" -in "$partial" -out "$final.partial"
  rm -f "$partial"
  # Read it back: an unreadable backup is worse than none, because it looks like one.
  openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$ZABA_BACKUP_PASSPHRASE_FILE" -in "$final.partial" | tar -tf - >/dev/null \
    || { rm -f "$final.partial"; die "the encrypted backup could not be read back"; }
  mv "$final.partial" "$final"
else
  final="$target/zaba-$stamp.tar"
  tar -tf "$partial" >/dev/null || { rm -f "$partial"; die "the backup could not be read back"; }
  mv "$partial" "$final"
  echo "WARNING: this backup is NOT encrypted and contains the stack's secrets (set ZABA_BACKUP_PASSPHRASE_FILE)." >&2
fi

# Keep the newest $keep (the names sort by time). `find`, not `ls`: with pipefail a glob
# that matches nothing (there is no .tar next to the .tar.enc files) would end the script.
find "$target" -maxdepth 1 -type f \( -name 'zaba-*.tar' -o -name 'zaba-*.tar.enc' \) | sort -r | tail -n +"$((keep + 1))" | while read -r old; do
  rm -f "$old"
  echo "pruned $old"
done

echo "Backup written: $final ($(du -h "$final" | cut -f1); $entries dump entries)"
