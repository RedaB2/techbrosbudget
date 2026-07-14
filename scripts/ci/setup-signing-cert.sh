#!/usr/bin/env bash
set -euo pipefail

# Imports a single, persistent Apple Distribution certificate into a temporary
# keychain so xcodebuild reuses it instead of minting a brand-new certificate on
# every ephemeral runner. Without this, `-allowProvisioningUpdates` requests a
# fresh certificate each run and quickly exhausts the account certificate limit.

: "${DIST_CERT_P12_BASE64:?Set DIST_CERT_P12_BASE64 (base64 of your Apple Distribution .p12).}"
: "${DIST_CERT_PASSWORD:?Set DIST_CERT_PASSWORD (password used when exporting the .p12).}"

keychain_path="$RUNNER_TEMP/signing.keychain-db"
keychain_password="$(uuidgen)"
cert_path="$RUNNER_TEMP/dist-cert.p12"

printf '%s' "$DIST_CERT_P12_BASE64" | base64 --decode > "$cert_path"

# Create and unlock a dedicated keychain for this run.
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"

# Import the distribution identity (certificate + private key).
security import "$cert_path" \
  -P "$DIST_CERT_PASSWORD" \
  -A -t cert -f pkcs12 \
  -k "$keychain_path"

# Let codesign/xcodebuild use the private key without an interactive prompt.
security set-key-partition-list \
  -S apple-tool:,apple: \
  -k "$keychain_password" \
  "$keychain_path" >/dev/null

# Put our keychain first in the search list so xcodebuild finds the identity.
existing_keychains="$(security list-keychains -d user | sed 's/["[:space:]]//g')"
# shellcheck disable=SC2086
security list-keychains -d user -s "$keychain_path" $existing_keychains

rm -f "$cert_path"

echo "Imported signing identities:"
security find-identity -v -p codesigning "$keychain_path"
