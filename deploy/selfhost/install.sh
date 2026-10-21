#!/usr/bin/env bash
# Installs or updates the self-hosted staging stack: the official Supabase
# self-hosting setup (pinned release) plus Caddy and the Cloudflare Tunnel.
#
#   cp zaba-selfhost.env.example zaba-selfhost.env   # edit it first
#   ./install.sh
#
# Safe to run again: secrets are generated only once, and it re-applies the
# settings, new migrations and the tunnel. Needs docker (compose >= 2.24), git,
# openssl and curl on the server.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${ZABA_SELFHOST_ENV:-$here/zaba-selfhost.env}"

die() { echo "ERROR: $*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }

[ -f "$config" ] || die "$config not found. Copy zaba-selfhost.env.example to zaba-selfhost.env and edit it."
set -a
# shellcheck disable=SC1090
. "$config"
set +a

for var in ZABA_APP_HOST ZABA_API_HOST ZABA_ADMIN_HOST ZABA_STACK_DIR SUPABASE_SELFHOST_REF; do
  [ -n "${!var:-}" ] || die "$var is empty in $config"
done
case "$ZABA_APP_HOST$ZABA_API_HOST$ZABA_ADMIN_HOST" in
  *example.com*) die "The host names in $config still say example.com. Use your own domain." ;;
esac

say "Checking the tools"
for tool in docker git openssl curl; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done
compose_version="$(docker compose version --short 2>/dev/null | sed 's/^v//')" || die "docker compose is not available"
major="${compose_version%%.*}"
minor="$(echo "$compose_version" | cut -d. -f2)"
if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 24 ]; }; then
  die "docker compose $compose_version is too old (need 2.24 or newer for the override files)"
fi

stack="$ZABA_STACK_DIR"
upstream="$stack/.upstream"
mkdir -p "$stack"

say "Fetching the official Supabase self-hosting files ($SUPABASE_SELFHOST_REF)"
if [ ! -d "$upstream/.git" ]; then
  git clone --quiet --depth 1 --branch "$SUPABASE_SELFHOST_REF" --filter=blob:none --sparse \
    https://github.com/supabase/supabase.git "$upstream"
else
  git -C "$upstream" fetch --quiet --depth 1 origin "refs/tags/$SUPABASE_SELFHOST_REF:refs/tags/$SUPABASE_SELFHOST_REF"
  git -C "$upstream" checkout --quiet "$SUPABASE_SELFHOST_REF"
fi
git -C "$upstream" sparse-checkout set docker >/dev/null
# Copies the official files over the stack directory. It never touches `.env`
# or the database files, which do not exist upstream.
cp -a "$upstream/docker/." "$stack/"
printf 'ref=%s\n' "$SUPABASE_SELFHOST_REF" > "$stack/.supabase-version"

cd "$stack"

set_env() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  { grep -v "^${key}=" .env || true; } > "$tmp"
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  cat "$tmp" > .env
  rm -f "$tmp"
}

say "Secrets"
if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
fi
if [ ! -f .zaba-secrets-generated ]; then
  # Generated once. Running these again would change the database password of
  # an existing database. Their output (the keys) is not shown; see
  # `sh run.sh secrets` when you need it.
  sh utils/generate-keys.sh --update-env >/dev/null
  sh utils/add-new-auth-keys.sh --update-env >/dev/null
  touch .zaba-secrets-generated
  echo "Generated new secrets into $stack/.env (mode 600). Keep that file safe."
else
  echo "Secrets already generated, left unchanged."
fi

say "Settings"
scheme="${ZABA_PUBLIC_SCHEME:-https}"
set_env SUPABASE_PUBLIC_URL "$scheme://$ZABA_API_HOST"
set_env API_EXTERNAL_URL "$scheme://$ZABA_API_HOST/auth/v1"
set_env SITE_URL "$scheme://$ZABA_APP_HOST"
set_env ADDITIONAL_REDIRECT_URLS "$scheme://$ZABA_APP_HOST,$scheme://$ZABA_ADMIN_HOST"
# The demo has no outgoing email: accounts are confirmed on sign-up.
set_env ENABLE_EMAIL_AUTOCONFIRM true
set_env ENABLE_PHONE_SIGNUP false
set_env ENABLE_PHONE_AUTOCONFIRM false
# The payment provider's signing secret. The payment functions refuse to work
# without it. Generated once, like the others: a new one would make payment
# sessions that are still open invalid.
if ! grep -q '^FAKE_PAYMENT_WEBHOOK_SECRET=.' .env; then
  set_env FAKE_PAYMENT_WEBHOOK_SECRET "$(openssl rand -hex 32)"
fi
set_env ZABA_APP_HOST "$ZABA_APP_HOST"
set_env ZABA_API_HOST "$ZABA_API_HOST"
set_env ZABA_ADMIN_HOST "$ZABA_ADMIN_HOST"
set_env ZABA_HTTP_BIND "${ZABA_HTTP_BIND:-127.0.0.1}"
set_env ZABA_HTTP_PORT "${ZABA_HTTP_PORT:-8080}"
set_env CLOUDFLARE_TUNNEL_TOKEN "${CLOUDFLARE_TUNNEL_TOKEN:-}"
chmod 600 .env

say "Zaba overlay (Caddy, tunnel)"
mkdir -p zaba/web/app zaba/web/admin
cp "$here/docker-compose.zaba.yml" docker-compose.zaba.yml
cp "$here/Caddyfile" zaba/Caddyfile
[ -f zaba/web/app/index.html ] || printf '<!doctype html><meta charset="utf-8"><title>Zaba</title><p>Zaba staging: the app has not been deployed yet.</p>\n' > zaba/web/app/index.html
[ -f zaba/web/admin/index.html ] || printf '<!doctype html><meta charset="utf-8"><title>Zaba admin</title><p>The admin page comes in a later step.</p>\n' > zaba/web/admin/index.html
if ! grep -q 'docker-compose.zaba.yml' .env; then
  sh run.sh config add zaba >/dev/null
fi

say "Edge Functions (payments)"
# Functions are installed by placing their files where the Edge Runtime looks.
# The official `main` router stays; Zaba's functions and their shared code are
# copied next to it. Test files are not needed on the server.
repo="$(cd "$here/../.." && pwd)"
mkdir -p volumes/functions
cp -a "$repo/supabase/functions/." volumes/functions/
find volumes/functions -name '*.test.ts' -delete

say "Pulling images (the first time this is several GB)"
docker compose pull --quiet

say "Starting the stack"
sh run.sh start
# Picks up a changed Caddyfile (its admin endpoint is off, so no live reload)
# and changed function code.
docker compose restart caddy functions >/dev/null
# The gateway health-checks the functions every 5 seconds and needs two good
# answers before it sends traffic to a restarted container, so for a short while
# it answers 503. Wait until a function answers (the empty request is refused
# by the function itself, which is the right answer).
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' -X POST \
    "http://127.0.0.1:${API_GW_HTTP_PORT:-8000}/functions/v1/payments-webhook" || true)"
  case "$code" in 000|503) sleep 2 ;; *) break ;; esac
done
case "$code" in 000|503) echo "WARNING: the payment functions do not answer yet (HTTP $code). Check: sh run.sh logs functions" ;; esac
if [ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]; then
  docker compose --profile tunnel up -d --wait
  tunnel="running"
else
  tunnel="not started (no CLOUDFLARE_TUNNEL_TOKEN yet)"
fi

say "Database: migrations and seed data"
"$here/migrate.sh"
"$here/seed.sh"

anon_key="$(grep '^ANON_KEY=' .env | cut -d= -f2-)"
cat <<EOF

==> Done.

  App:     $scheme://$ZABA_APP_HOST
  API:     $scheme://$ZABA_API_HOST
  Admin:   $scheme://$ZABA_ADMIN_HOST   (placeholder for now)
  Tunnel:  $tunnel
  Direct:  http://${ZABA_HTTP_BIND:-127.0.0.1}:${ZABA_HTTP_PORT:-8080}  (Host header decides which of the three)

Put this into config/staging.json on your development machine. The anon key is
public by design (the app ships it, RLS protects the data). It is the legacy
JWT key on purpose: this self-hosting release accepts only that one on the
Realtime WebSocket (the newer sb_publishable_ key works for REST only).

  {
    "APP_ENV": "staging",
    "SUPABASE_URL": "$scheme://$ZABA_API_HOST",
    "SUPABASE_ANON_KEY": "$anon_key"
  }

Secrets (never share or commit them) are in $stack/.env, show them with:
  cd $stack && sh run.sh secrets
EOF
