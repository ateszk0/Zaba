#!/usr/bin/env bash
# Serves the app and the admin page from this computer to phones on the same Wi-Fi,
# against the local Supabase (`npx supabase start`). For trying the app on a real
# phone before anything is deployed: no Cloudflare or Supabase account needed.
#
#   tool/lan_preview.sh              # picks the Wi-Fi address if there is only one
#   tool/lan_preview.sh 192.168.1.20 # or name it
#
# It builds into app/build/lan (never into app/build/demo, which is what gets
# deployed), and serves with the same headers as the demo, from `wrangler dev`.
# Needs the local stack running and the demo accounts created:
#   npx supabase start
#   python3 tool/create_demo_user.py --from-local
#   python3 tool/create_staff_user.py --from-local --role operator
#
# It is plain http on the home network, with the local development accounts and
# keys: for your own phones only, never for somebody else's. The firewall must let
# the phone reach ports 8787, 8788 and 54321 of this computer (ufw: see the docs).
# Stop it with Ctrl-C.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
cd "$repo"

die() { echo "ERROR: $*" >&2; exit 1; }

ip="${1:-}"
if [ -z "$ip" ]; then
  # Real network cards only: not loopback, containers, bridges or VPN tunnels (the
  # default route often goes through a VPN, whose address no phone can reach).
  candidates="$(ip -4 -o addr show scope global 2>/dev/null \
    | awk '$2 !~ /^(lo|docker|br-|veth|virbr|tun|tap|wg|proton|tailscale|zt)/ {split($4, a, "/"); print $2 " " a[1]}')"
  [ -n "$candidates" ] || die "no network address found; give it: $0 <address of this computer>"
  if [ "$(printf '%s\n' "$candidates" | wc -l)" -ne 1 ]; then
    printf '%s\n' "More than one network address; run again with the Wi-Fi one:" >&2
    printf '  %s\n' "$candidates" >&2
    exit 1
  fi
  ip="${candidates#* }"
fi

status="$(npx supabase status -o json 2>/dev/null)" \
  || die "the local Supabase is not running (npx supabase start)"
read -r api key < <(STATUS_JSON="$status" python3 - "$ip" <<'PY'
import json, os, sys
from urllib.parse import urlparse
s = json.loads(os.environ["STATUS_JSON"])
u = urlparse(s["API_URL"])
print(f"http://{sys.argv[1]}:{u.port}", s.get("PUBLISHABLE_KEY") or s["ANON_KEY"])
PY
)

lan="$repo/app/build/lan"
mkdir -p "$lan"

# The customer build gets no staff password; the admin build gets the local one, so
# the demo button works (the local stack only, which is why this is never deployed).
python3 - "$lan" "$api" "$key" <<'PY'
import json, sys
lan, api, key = sys.argv[1:]
base = {"APP_ENV": "demo", "SUPABASE_URL": api, "SUPABASE_ANON_KEY": key,
        "DEMO_EMAIL": "demo@zaba.example", "DEMO_PASSWORD": "Demo-jelszo-1"}
json.dump(base, open(f"{lan}/app.json", "w"))
json.dump({**base, "ADMIN_DEMO_EMAIL": "konyha@zaba.example",
           "ADMIN_DEMO_PASSWORD": "Konyha-jelszo-1"}, open(f"{lan}/admin.json", "w"))
PY

for part in app admin; do
  ZABA_BUILD_OUT="$lan/$part" "$repo/deploy/demo/build-web.sh" "$part" "$lan/$part.json"
  cat > "$lan/wrangler.$part.jsonc" <<EOF
{
  "name": "zaba-$part-lan",
  "compatibility_date": "2026-10-01",
  "assets": { "directory": "$lan/$part", "not_found_handling": "single-page-application" }
}
EOF
done

# npx starts node, which starts the Workers runtime: stop the whole chain, or the
# ports stay taken and the next run cannot start.
kill_tree() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$child"; done
  kill "$1" 2>/dev/null || true
}
pids=()
cleanup() {
  trap - EXIT INT TERM
  local pid
  for pid in "${pids[@]}"; do kill_tree "$pid"; done
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Two instances need an inspector port each, or the second one cannot start.
npx wrangler dev --config "$lan/wrangler.app.jsonc" --ip 0.0.0.0 --port 8787 \
  --inspector-port 9331 >"$lan/app.log" 2>&1 &
pids+=("$!")
npx wrangler dev --config "$lan/wrangler.admin.jsonc" --ip 0.0.0.0 --port 8788 \
  --inspector-port 9332 >"$lan/admin.log" 2>&1 &
pids+=("$!")

for part in app:8787 admin:8788; do
  up=""
  for _ in $(seq 1 60); do
    if curl -s -o /dev/null -m 2 "http://127.0.0.1:${part#*:}/"; then up=yes; break; fi
    sleep 1
  done
  [ -n "$up" ] || { tail -5 "$lan/${part%:*}.log" >&2; die "the ${part%:*} server did not start (log: $lan/${part%:*}.log)"; }
done

cat <<EOF

Ready. On a phone on the same Wi-Fi open:

  the app    http://$ip:8787
  the admin  http://$ip:8788   (better on a computer; the demo staff button is filled in)

The backend the pages talk to is $api. Stop with Ctrl-C.
EOF
wait
