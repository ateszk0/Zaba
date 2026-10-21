#!/usr/bin/env bash
# Builds and deploys a part of the demo environment to Cloudflare from this machine.
#
#   deploy/demo/deploy-web.sh app       # the customer app
#   deploy/demo/deploy-web.sh admin     # the admin page
#   deploy/demo/deploy-web.sh apk       # the Android download page with the APK
#
# Each part is a site of its own (a Cloudflare Worker that only serves files), so
# deploying one never touches the others. Needs config/demo.json (see
# config/demo.example.json) and a Cloudflare login: either `npx wrangler login`
# once, or CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment.
# docs/demo-environment.md has the whole procedure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

which="${1:-}"
case "$which" in
  app|admin) "$here/build-web.sh" "$which" ;;
  apk) "$here/build-apk.sh" ;;
  *) echo "Usage: $0 app|admin|apk" >&2; exit 1 ;;
esac

cd "$repo"
npx wrangler deploy --config "deploy/demo/wrangler.$which.jsonc"
