#!/usr/bin/env bash
# Makes the key the demo APK is signed with, OUTSIDE the repository, and tells the
# Android build where it is (app/android/key.properties, which git ignores).
#
#   tool/android/create_demo_keystore.sh
#
# Keep ~/.zaba-keys/ safe and back it up: an update of an installed APK must be
# signed with the same key, or Android refuses to install it over the old one. For
# the finished product the owner makes their own key; this one is the demo's.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
keys="${ZABA_KEYS_DIR:-$HOME/.zaba-keys}"
keystore="$keys/zaba-demo.jks"
properties="$repo/app/android/key.properties"

command -v keytool >/dev/null || { echo "ERROR: keytool (part of a JDK) is not installed." >&2; exit 1; }
command -v openssl >/dev/null || { echo "ERROR: openssl is not installed." >&2; exit 1; }
[ ! -e "$keystore" ] || { echo "ERROR: $keystore already exists; it is not overwritten." >&2; exit 1; }
[ ! -e "$properties" ] || { echo "ERROR: $properties already exists; it is not overwritten." >&2; exit 1; }

mkdir -p "$keys"
chmod 700 "$keys"

# One random password for the store and the key. Passed through the environment,
# not the command line, so it does not show up in the process list.
ZABA_KEY_PASSWORD="$(openssl rand -base64 36 | tr -d '/+=\n' | cut -c1-32)"
export ZABA_KEY_PASSWORD
keytool -genkeypair -keystore "$keystore" -alias zaba-demo \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Zaba demo, O=Zaba, C=HU" \
  -storepass:env ZABA_KEY_PASSWORD -keypass:env ZABA_KEY_PASSWORD
chmod 600 "$keystore"

umask 077
cat > "$properties" <<PROPS
storePassword=$ZABA_KEY_PASSWORD
keyPassword=$ZABA_KEY_PASSWORD
keyAlias=zaba-demo
storeFile=$keystore
PROPS

echo "Key:        $keystore"
echo "Properties: $properties (not committed; the passwords are in it)"
echo "Back up $keys somewhere safe."
