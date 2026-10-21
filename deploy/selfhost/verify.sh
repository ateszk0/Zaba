#!/usr/bin/env bash
# Checks an installed self-hosted stack from the outside, and changes nothing. Run it after
# install.sh, after every change to the server, and from time to time (a cron job that mails
# its output when the exit status is not 0 is a cheap monitor).
#
#   deploy/selfhost/verify.sh
#
# Prints one line per check: "ok", "WARN" (worth a look) or "FAILED" (fix it). Exits 1 when
# something FAILED. What it looks at: that every container is up and healthy, that nothing
# but the local gateway and Caddy is published on the machine, that Caddy serves what it
# should and hides what it must (Studio, the Postgres meta API, Storage), the security
# headers, that no secret still has the value of the official placeholder, that the database
# has all the migrations, that a backup is fresh, and that the disk and the logs are bounded.
set -uo pipefail

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
cd "$stack" || exit 1

env_value() { grep "^$1=" .env | head -1 | cut -d= -f2-; }
app_host="$(env_value ZABA_APP_HOST)"; api_host="$(env_value ZABA_API_HOST)"; admin_host="$(env_value ZABA_ADMIN_HOST)"
bind="$(env_value ZABA_HTTP_BIND)"; port="$(env_value ZABA_HTTP_PORT)"
base="http://${bind:-127.0.0.1}:${port:-8080}"
[ "${bind:-127.0.0.1}" = "0.0.0.0" ] && base="http://127.0.0.1:${port:-8080}"
key="$(env_value SUPABASE_PUBLISHABLE_KEY)"

failed=0
ok() { printf 'ok      %s\n' "$1"; }
warn() { printf 'WARN    %s\n' "$1"; }
bad() { printf 'FAILED  %s\n' "$1"; failed=1; }
check() { if [ "$2" = "yes" ]; then ok "$1"; else bad "$1${3:+  [$3]}"; fi; }

# status of a request to Caddy for a host and path; extra curl arguments follow
code() { local host="$1" path="$2"; shift 2; curl -s -o /dev/null -m 8 -w '%{http_code}' -H "Host: $host" "$@" "$base$path" || echo 000; }
header() { local host="$1" path="$2" name="$3"; curl -s -D - -o /dev/null -m 8 -H "Host: $host" "$base$path" | grep -i "^$name:" | head -1 | tr -d '\r'; }

echo "== containers"
expected="api-gw auth caddy db functions imgproxy meta realtime rest storage studio supavisor"
[ -n "$(env_value CLOUDFLARE_TUNNEL_TOKEN)" ] && expected="$expected cloudflared"
states="$(docker compose --profile tunnel ps --format '{{.Service}} {{.State}} {{.Health}}' 2>/dev/null)"
for service in $expected; do
  line="$(echo "$states" | grep "^$service " | head -1)"
  case "$line" in
    "$service running healthy"|"$service running ") ok "$service is running" ;;
    "") bad "$service is not running (or missing)" ;;
    *) bad "$service: ${line#"$service "}" ;;
  esac
done

echo "== what is published on this machine"
published="$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E '(0\.0\.0\.0|\[::\]):[0-9]+->' || true)"
if [ "${bind:-127.0.0.1}" = "0.0.0.0" ]; then
  warn "Caddy is published on every interface (ZABA_HTTP_BIND=0.0.0.0): fine for a test on the local network, not for a server on the internet"
  published="$(echo "$published" | grep -v zaba-caddy || true)"
fi
check "nothing is published on all interfaces" "$([ -z "$published" ] && echo yes || echo no)" "$published"
check "the database and the pooler publish no port" "$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E 'supabase-(db|pooler)' | grep -q -- '->' && echo no || echo yes)"

echo "== what Caddy serves"
check "the app host answers /healthz" "$([ "$(code "$app_host" /healthz)" = 200 ] && echo yes || echo no)"
check "the app host serves the app" "$([ "$(code "$app_host" /)" = 200 ] && echo yes || echo no)"
check "a client-side route falls back to the app" "$([ "$(code "$app_host" /menu)" = 200 ] && echo yes || echo no)"
check "a missing asset is a real 404" "$([ "$(code "$app_host" /nothing-here.js)" = 404 ] && echo yes || echo no)"
check "the admin host answers" "$([ "$(code "$admin_host" /)" = 200 ] && echo yes || echo no)"
check "the catalog is readable through the API host" "$([ "$(code "$api_host" '/rest/v1/catalog_products?select=id&limit=1' -H "apikey: $key")" = 200 ] && echo yes || echo no)"
check "auth answers" "$([ "$(code "$api_host" /auth/v1/health -H "apikey: $key")" = 200 ] && echo yes || echo no)"
check "an empty payment webhook call is refused by the function" "$([ "$(code "$api_host" /functions/v1/payments-webhook -X POST -H 'Content-Type: application/json' -d '{}')" = 400 ] && echo yes || echo no)"
for hidden in / /studio /pg/tables /storage/v1/bucket /analytics/v1/ /graphql/v1; do
  check "the API host hides $hidden" "$([ "$(code "$api_host" "$hidden" -H "apikey: $key")" = 404 ] && echo yes || echo no)" "HTTP $(code "$api_host" "$hidden" -H "apikey: $key")"
done
check "the auth admin endpoints refuse a public key" "$(case "$(code "$api_host" /auth/v1/admin/users -H "apikey: $key")" in 401|403) echo yes ;; *) echo no ;; esac)"
check "an unknown host is a 404" "$([ "$(code unknown.invalid /)" = 404 ] && echo yes || echo no)"

echo "== headers"
csp="$(header "$app_host" / content-security-policy)"
check "the app has a Content-Security-Policy" "$([ -n "$csp" ] && echo yes || echo no)"
check "the policy lets the app talk to the API host and nobody else" "$(echo "$csp" | grep -q "$api_host" && echo "$csp" | grep -qE "default-src 'self'" && echo yes || echo no)"
check "the app sends nosniff" "$([ -n "$(header "$app_host" / x-content-type-options)" ] && echo yes || echo no)"
check "the admin page cannot be framed" "$([ -n "$(header "$admin_host" / x-frame-options)" ] && echo yes || echo no)"

echo "== secrets"
check ".env is private (mode 600)" "$([ "$(stat -c %a .env)" = 600 ] && echo yes || echo no)" "mode $(stat -c %a .env)"
for name in POSTGRES_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY SECRET_KEY_BASE VAULT_ENC_KEY DASHBOARD_PASSWORD PG_META_CRYPTO_KEY; do
  placeholder="$(grep "^$name=" .env.example 2>/dev/null | head -1 | cut -d= -f2-)"
  current="$(env_value "$name")"
  if [ -z "$current" ]; then warn "$name is empty"
  elif [ -n "$placeholder" ] && [ "$current" = "$placeholder" ]; then bad "$name still has the official placeholder value"
  else ok "$name is not the placeholder"; fi
done
[ ${#key} -gt 20 ] || bad "SUPABASE_PUBLISHABLE_KEY is missing"

echo "== payments"
fake="$(env_value FAKE_PAYMENTS_ENABLED)"
# An empty call to payments-create is answered 503 when the fake card step is off, and 401
# (not signed in) when it is on: that shows what the running functions do, not what .env says.
live="$(code "$api_host" /functions/v1/payments-create -X POST -H 'Content-Type: application/json' -d '{}')"
if [ "$fake" = "true" ]; then
  warn "the demo's fake card step is ON (FAKE_PAYMENTS_ENABLED=true): fine for a demo, it must be off before real customers pay"
  check "the running functions agree that it is on" "$([ "$live" = 401 ] && echo yes || echo no)" "payments-create answered HTTP $live; recreate the functions: docker compose up -d functions"
else
  ok "the demo's fake card step is off"
  check "the running functions agree that it is off" "$([ "$live" = 503 ] && echo yes || echo no)" "payments-create answered HTTP $live; recreate the functions: docker compose up -d functions"
fi

echo "== database"
psql_db() { docker compose exec -T db psql -U supabase_admin -d postgres -At -X "$@" 2>/dev/null; }
applied="$(psql_db -c 'select count(*) from supabase_migrations.schema_migrations')"
wanted="$(find "$repo/supabase/migrations" -name '*.sql' | wc -l)"
check "all $wanted migrations are applied" "$([ "$applied" = "$wanted" ] && echo yes || echo no)" "applied: ${applied:-none}"
products="$(psql_db -c 'select count(*) from public.products')"
check "the menu has products" "$([ "${products:-0}" -gt 0 ] && echo yes || echo no)"
expiry="$(psql_db -c "select count(*) from cron.job where jobname = 'zaba-expire-unpaid' and active")"
if [ "${expiry:-0}" = "1" ]; then ok "unpaid orders expire (pg_cron job zaba-expire-unpaid)"
else warn "no job cancels orders that are never paid: places in the delivery slots would stay taken (deploy/selfhost/schedule.sh)"; fi

echo "== operations"
backup_dir="${ZABA_BACKUP_DIR:-$HOME/zaba-backups}"
newest="$(find "$backup_dir" -maxdepth 1 -type f -name 'zaba-*.tar*' -printf '%T@\n' 2>/dev/null | sort -nr | head -1)"
if [ -z "$newest" ]; then warn "no backup found in $backup_dir (deploy/selfhost/backup.sh)"
elif [ "$(( $(date +%s) - ${newest%.*} ))" -gt 93600 ]; then warn "the newest backup in $backup_dir is older than 26 hours"
else ok "a backup from the last 26 hours exists"; fi
used="$(df --output=pcent "$stack" | tail -1 | tr -dc '0-9')"
if [ "${used:-0}" -ge 85 ]; then bad "the disk of $stack is ${used}% full"; elif [ "${used:-0}" -ge 70 ]; then warn "the disk of $stack is ${used}% full"; else ok "the disk has room (${used}% used)"; fi
check "container logs are rotated" "$([ "$(docker inspect --format '{{index .HostConfig.LogConfig.Config "max-size"}}' supabase-db 2>/dev/null)" != "" ] && echo yes || echo no)"

echo
if [ "$failed" = 0 ]; then echo "Everything that matters is in order."; else echo "Something FAILED: see above."; fi
exit "$failed"
