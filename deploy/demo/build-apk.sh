#!/usr/bin/env bash
# Builds the signed Android APK of the demo, checks it, and prepares the download
# site in app/build/demo/apk (deploy it with deploy-web.sh apk).
#
#   deploy/demo/build-apk.sh                      # uses config/demo.json
#   deploy/demo/build-apk.sh path/to/other.json
#
# Needs the Android SDK (flutter doctor), a JDK, and the demo signing key
# (tool/android/create_demo_keystore.sh). Refuses an APK that is not signed with
# that key, or that cannot reach the network.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
config="${1:-$repo/config/demo.json}"

[ -f "$config" ] || { echo "ERROR: $config not found (copy config/demo.example.json and fill it in)." >&2; exit 1; }
[ -f "$repo/app/android/key.properties" ] || {
  echo "ERROR: there is no signing key yet. Run tool/android/create_demo_keystore.sh first." >&2
  exit 1
}

# The Android SDK's build tools: apksigner and aapt2 of the newest installed version.
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
tools="$(ls -d "$sdk"/build-tools/* 2>/dev/null | sort -V | tail -1)"
[ -n "$tools" ] && [ -x "$tools/apksigner" ] || { echo "ERROR: no Android build-tools found under $sdk." >&2; exit 1; }

cd "$repo/app"
# 64-bit ARM only (practically every Android phone since 2017): with the 32-bit
# build as well the APK is ~40 MB, over the 25 MiB Cloudflare serves per file.
flutter build apk --release --target-platform android-arm64 --dart-define-from-file="$config"
apk="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$apk" ] || { echo "ERROR: $apk was not produced." >&2; exit 1; }

echo "--- checking the APK"
# apksigner's own Java warnings are noise; its errors are not, so keep those.
errors="$(mktemp)"
trap 'rm -f "$errors"' EXIT
certs="$("$tools/apksigner" verify --print-certs "$apk" 2>"$errors")" || { cat "$errors" >&2; exit 1; }
echo "$certs" | grep -E "Signer #1 certificate (DN|SHA-256)" || true
if echo "$certs" | grep -qi "Android Debug"; then
  echo "ERROR: the APK is signed with the debug key, not the demo key." >&2
  exit 1
fi
echo "$certs" | grep -q "CN=Zaba demo" || { echo "ERROR: the APK is not signed with the Zaba demo key." >&2; exit 1; }

badging="$("$tools/aapt2" dump badging "$apk")"
echo "$badging" | grep -E "^package:" | cut -d' ' -f1-4
echo "$badging" | grep -q "uses-permission: name='android.permission.INTERNET'" || {
  echo "ERROR: the APK does not declare the INTERNET permission: it could not reach the backend." >&2
  exit 1
}
echo "$badging" | grep -E "^(application-label|uses-permission):" | sed 's/^/  /'

size_bytes="$(stat -c %s "$apk")"
size_mib=$(( size_bytes / 1024 / 1024 ))
if [ "$size_bytes" -gt $(( 25 * 1024 * 1024 )) ]; then
  echo "ERROR: the APK is $size_mib MiB; Cloudflare serves files up to 25 MiB." >&2
  exit 1
fi

site="$repo/app/build/demo/apk"
rm -rf "$site"
mkdir -p "$site"
cp "$apk" "$site/zaba-demo.apk"
sha="$(sha256sum "$site/zaba-demo.apk" | cut -d' ' -f1)"
version="$(echo "$badging" | sed -n "s/^package:.*versionName='\([^']*\)'.*/\1/p")"
sed -e "s|__SHA256__|$sha|g" -e "s|__VERSION__|$version|g" -e "s|__SIZE__|$(awk "BEGIN { printf \"%.1f\", $size_bytes / 1048576 }") MB|g" \
  "$here/apk/index.html" > "$site/index.html"
cat > "$site/_headers" <<'HEADERS'
/*
  X-Content-Type-Options: nosniff
  X-Robots-Tag: noindex, nofollow
  Referrer-Policy: no-referrer
  Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
/zaba-demo.apk
  Content-Type: application/vnd.android.package-archive
  Content-Disposition: attachment; filename="zaba-demo.apk"
HEADERS

echo "APK ready: $site/zaba-demo.apk ($size_mib MiB, version $version, sha256 ${sha:0:16}...)"
