#!/usr/bin/env bash
# Builds the Flutter web app on your development machine and copies it to the staging
# server, where Caddy serves it.
#
#   deploy/selfhost/deploy-web.sh user@server          # the customer app
#   deploy/selfhost/deploy-web.sh user@server admin    # the admin page
#   deploy/selfhost/deploy-web.sh local:/path/to/stack [app|admin]   # the stack is on this machine
#
# Needs config/staging.json (copy config/staging.example.json; the installer prints the
# values) and flutter, python3, ssh and rsync on this machine.
#
# It uses the demo's build (deploy/demo/build-web.sh): the rendering engine comes from the
# server itself, not from Google's CDN, and the page runs without dynamically generated
# code, which is what the Content-Security-Policy of the Caddyfile allows. The admin page also
# gets its own web manifest that way.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

target="${1:-}"
which="${2:-app}"
[ -n "$target" ] || { echo "Usage: $0 user@server|local:/path/to/stack [app|admin]" >&2; exit 1; }
case "$which" in
  app|admin) ;;
  *) echo "ERROR: the second argument is 'app' or 'admin', not '$which'." >&2; exit 1 ;;
esac

config="$repo/config/staging.json"
[ -f "$config" ] || { echo "ERROR: $config not found (copy config/staging.example.json)." >&2; exit 1; }

# Where the stack lives on the server, relative to the login directory.
remote_stack="${ZABA_REMOTE_STACK_DIR:-zaba-stack}"

# Its own output folder, so a build for the server never replaces the demo's.
out="$repo/app/build/selfhost/$which"
ZABA_BUILD_OUT="$out" "$repo/deploy/demo/build-web.sh" "$which" "$config"
# That is Cloudflare's headers file; here Caddy sets the headers, and the file would just
# be served to anyone who asks for it.
rm -f "$out/_headers"

# --delete removes files of an older build that no longer exist. --delay-updates puts all the
# changed files in place at the end, so a visitor never gets a half-updated page.
case "$target" in
  local:*) rsync -a --delete --delay-updates "$out/" "${target#local:}/zaba/web/$which/" ;;
  *) rsync -az --delete --delay-updates "$out/" "$target:$remote_stack/zaba/web/$which/" ;;
esac
echo "Deployed. Open the app host in a browser (hard-reload once if you had an older version open)."
