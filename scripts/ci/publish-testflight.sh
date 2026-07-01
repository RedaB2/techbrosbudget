#!/usr/bin/env bash
set -euo pipefail

: "${ASC_APP_ID:?Set ASC_APP_ID.}"
: "${ASC_KEY_ID:?Set ASC_KEY_ID.}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID.}"
: "${ASC_PRIVATE_KEY_PATH:?setup-asc-key.sh must set ASC_PRIVATE_KEY_PATH.}"
: "${XCODE_AUTH_KEY_PATH:?setup-asc-key.sh must set XCODE_AUTH_KEY_PATH.}"
: "${PROJECT_PATH:?Set PROJECT_PATH.}"
: "${SCHEME:?Set SCHEME.}"
: "${CONFIGURATION:?Set CONFIGURATION.}"
: "${IOS_MARKETING_VERSION:?Set IOS_MARKETING_VERSION.}"
: "${TESTFLIGHT_GROUP:?Set TESTFLIGHT_GROUP.}"

mkdir -p .asc/artifacts

next_build_number="$(
  asc builds next-build-number \
    --app "$ASC_APP_ID" \
    --version "$IOS_MARKETING_VERSION" \
    --platform IOS \
    --initial-build-number 1 \
    --output json | jq -r '.nextBuildNumber'
)"

if [[ -z "$next_build_number" || "$next_build_number" == "null" ]]; then
  echo "Could not resolve next build number from App Store Connect." >&2
  exit 1
fi

archive_path=".asc/artifacts/TechBrosBudget-${IOS_MARKETING_VERSION}-${next_build_number}.xcarchive"
ipa_path=".asc/artifacts/TechBrosBudget-${IOS_MARKETING_VERSION}-${next_build_number}.ipa"

extra_flags=()
if [[ "${SUBMIT_EXTERNAL_REVIEW:-false}" == "true" ]]; then
  extra_flags+=(--submit --confirm)
fi

echo "Publishing TestFlight ${IOS_MARKETING_VERSION} (${next_build_number}) to ${TESTFLIGHT_GROUP}."

asc publish testflight \
  --app "$ASC_APP_ID" \
  --project "$PROJECT_PATH" \
  --scheme "$SCHEME" \
  --configuration "$CONFIGURATION" \
  --version "$IOS_MARKETING_VERSION" \
  --build-number "$next_build_number" \
  --archive-path "$archive_path" \
  --ipa-path "$ipa_path" \
  --export-options ".asc/export-options-app-store.plist" \
  --group "$TESTFLIGHT_GROUP" \
  --test-notes "Automated TestFlight build ${IOS_MARKETING_VERSION} (${next_build_number}) from ${GITHUB_SHA:-local}." \
  --locale "en-US" \
  --platform IOS \
  --clean \
  --wait \
  --timeout 90m \
  --archive-xcodebuild-flag=-destination \
  --archive-xcodebuild-flag=generic/platform=iOS \
  --archive-xcodebuild-flag=-allowProvisioningUpdates \
  --archive-xcodebuild-flag=-authenticationKeyPath \
  --archive-xcodebuild-flag="$XCODE_AUTH_KEY_PATH" \
  --archive-xcodebuild-flag=-authenticationKeyID \
  --archive-xcodebuild-flag="$ASC_KEY_ID" \
  --archive-xcodebuild-flag=-authenticationKeyIssuerID \
  --archive-xcodebuild-flag="$ASC_ISSUER_ID" \
  --archive-xcodebuild-flag="MARKETING_VERSION=${IOS_MARKETING_VERSION}" \
  --archive-xcodebuild-flag="CURRENT_PROJECT_VERSION=${next_build_number}" \
  --export-xcodebuild-flag=-allowProvisioningUpdates \
  --export-xcodebuild-flag=-authenticationKeyPath \
  --export-xcodebuild-flag="$XCODE_AUTH_KEY_PATH" \
  --export-xcodebuild-flag=-authenticationKeyID \
  --export-xcodebuild-flag="$ASC_KEY_ID" \
  --export-xcodebuild-flag=-authenticationKeyIssuerID \
  --export-xcodebuild-flag="$ASC_ISSUER_ID" \
  "${extra_flags[@]}"
