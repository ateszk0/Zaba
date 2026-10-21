#!/usr/bin/env bash
# Builds the customer app or the admin page for the demo environment into
# app/build/demo/<app|admin>, ready to be deployed to Cloudflare (deploy-web.sh).
#
#   deploy/demo/build-web.sh app                       # uses config/demo.json
#   deploy/demo/build-web.sh admin path/to/other.json
#
# The config is a --dart-define-from-file JSON (see config/demo.example.json). It
# only holds public values; for the build a customer can open, leave
# ADMIN_DEMO_EMAIL and ADMIN_DEMO_PASSWORD out of it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

which="${1:-}"
config="${2:-$repo/config/demo.json}"
case "$which" in
  app) entry="lib/main.dart" ;;
  admin) entry="lib/main_admin.dart" ;;
  *) echo "Usage: $0 app|admin [config.json]" >&2; exit 1 ;;
esac
[ -f "$config" ] || { echo "ERROR: $config not found (copy config/demo.example.json and fill it in)." >&2; exit 1; }

# The backend address, for the Content-Security-Policy: pages may only talk to it.
read -r supabase_http supabase_ws < <(python3 - "$config" <<'PY'
import json, sys
from urllib.parse import urlparse
url = json.load(open(sys.argv[1])).get("SUPABASE_URL", "")
parsed = urlparse(url)
if parsed.scheme not in ("http", "https") or not parsed.netloc:
    sys.exit("ERROR: SUPABASE_URL is missing or not an http(s) address in the config.")
origin = f"{parsed.scheme}://{parsed.netloc}"
print(origin, ("wss" if parsed.scheme == "https" else "ws") + "://" + parsed.netloc)
PY
)

out="$repo/app/build/demo/$which"
rm -rf "$out"
cd "$repo/app"
# --no-web-resources-cdn: the rendering engine (CanvasKit) comes from our own host,
# not from Google's, so the page makes no third-party request and works under the
# policy below. --csp: no dynamically generated code, so scripts need no 'unsafe-eval'.
flutter build web --release --no-web-resources-cdn --csp -t "$entry" \
  --dart-define-from-file="$config" --output "$out"

sed -e "s|__SUPABASE_HTTP__|$supabase_http|g" -e "s|__SUPABASE_WS__|$supabase_ws|g" \
  "$here/_headers.template" > "$out/_headers"

if [ "$which" = "admin" ]; then
  cp "$repo/app/web/manifest.admin.json" "$out/manifest.json"
fi
rm -f "$out/manifest.admin.json"

echo "Built $which into $out (backend: $supabase_http)"
