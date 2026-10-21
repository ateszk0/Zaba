#!/usr/bin/env bash
# Builds the Flutter web app on your development machine and copies it to the
# staging server, where Caddy serves it.
#
#   deploy/selfhost/deploy-web.sh user@server        # the customer app
#
# Needs config/staging.json (copy config/staging.example.json; the installer
# prints the values) and flutter, ssh and rsync on this machine.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

target="${1:-}"
which="${2:-app}"
[ -n "$target" ] || { echo "Usage: $0 user@server [app]" >&2; exit 1; }
[ "$which" = "app" ] || { echo "ERROR: only the customer app exists so far; the admin page comes later." >&2; exit 1; }

config="$repo/config/staging.json"
[ -f "$config" ] || { echo "ERROR: $config not found (copy config/staging.example.json)." >&2; exit 1; }

# Where the stack lives on the server, relative to the login directory.
remote_stack="${ZABA_REMOTE_STACK_DIR:-zaba-stack}"

cd "$repo/app"
flutter build web --release --dart-define-from-file="$config"

# --delete removes files of an older build that no longer exist.
rsync -az --delete build/web/ "$target:$remote_stack/zaba/web/$which/"
echo "Deployed. Open the app host in a browser (hard-reload once if you had an older version open)."
