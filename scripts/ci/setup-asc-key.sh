#!/usr/bin/env bash
set -euo pipefail

: "${ASC_KEY_ID:?Set ASC_KEY_ID.}"
: "${ASC_PRIVATE_KEY:?Set ASC_PRIVATE_KEY.}"

key_path="$RUNNER_TEMP/AuthKey_${ASC_KEY_ID}.p8"
printf '%b' "$ASC_PRIVATE_KEY" > "$key_path"
chmod 600 "$key_path"

{
  echo "ASC_BYPASS_KEYCHAIN=1"
  echo "ASC_PRIVATE_KEY_PATH=$key_path"
  echo "XCODE_AUTH_KEY_PATH=$key_path"
} >> "$GITHUB_ENV"
