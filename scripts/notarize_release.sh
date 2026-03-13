#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
APP_PATH="${APP_PATH:-${DIST_DIR}/ScreenTextGrab.app}"
ZIP_PATH="${ZIP_PATH:-${DIST_DIR}/ScreenTextGrab-notarization.zip}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT_DIR}/.build/release/ScreenTextGrab.xcarchive}"
NOTARY_PROFILE="${SCREEN_TEXT_GRAB_NOTARY_PROFILE:-}"
APPLE_ID="${SCREEN_TEXT_GRAB_APPLE_ID:-}"
APP_SPECIFIC_PASSWORD="${SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD:-}"
TEAM_ID="${SCREEN_TEXT_GRAB_NOTARY_TEAM_ID:-${SCREEN_TEXT_GRAB_TEAM_ID:-}}"
ASC_KEY_PATH="${SCREEN_TEXT_GRAB_ASC_KEY_PATH:-}"
ASC_KEY_ID="${SCREEN_TEXT_GRAB_ASC_KEY_ID:-}"
ASC_ISSUER_ID="${SCREEN_TEXT_GRAB_ASC_ISSUER_ID:-}"
XCODE_NOTARY_TIMEOUT_SECONDS="${SCREEN_TEXT_GRAB_XCODE_NOTARY_TIMEOUT_SECONDS:-1800}"
XCODE_NOTARY_POLL_INTERVAL_SECONDS="${SCREEN_TEXT_GRAB_XCODE_NOTARY_POLL_INTERVAL_SECONDS:-30}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command xcrun
require_command ditto
require_command codesign

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Release app not found: ${APP_PATH}" >&2
  exit 1
fi

APP_DIR="$(cd "$(dirname "${APP_PATH}")" && pwd -P)"
APP_PATH="${APP_DIR}/$(basename "${APP_PATH}")"
ZIP_DIR="$(cd "$(dirname "${ZIP_PATH}")" && pwd -P)"
ZIP_PATH="${ZIP_DIR}/$(basename "${ZIP_PATH}")"
ARCHIVE_DIR="$(cd "$(dirname "${ARCHIVE_PATH}")" && pwd -P)"
ARCHIVE_PATH="${ARCHIVE_DIR}/$(basename "${ARCHIVE_PATH}")"

authentication_mode=""
submit_args=()

if [[ -n "${NOTARY_PROFILE}" ]]; then
  authentication_mode="keychain-profile"
  submit_args+=(--keychain-profile "${NOTARY_PROFILE}")
elif [[ -n "${ASC_KEY_PATH}" || -n "${ASC_KEY_ID}" || -n "${ASC_ISSUER_ID}" ]]; then
  if [[ -z "${ASC_KEY_PATH}" || -z "${ASC_KEY_ID}" ]]; then
    echo "App Store Connect notarization requires SCREEN_TEXT_GRAB_ASC_KEY_PATH and SCREEN_TEXT_GRAB_ASC_KEY_ID." >&2
    exit 1
  fi

  authentication_mode="app-store-connect-api-key"
  submit_args+=(--key "${ASC_KEY_PATH}" --key-id "${ASC_KEY_ID}")
  if [[ -n "${ASC_ISSUER_ID}" ]]; then
    submit_args+=(--issuer "${ASC_ISSUER_ID}")
  fi
elif [[ -n "${APPLE_ID}" || -n "${APP_SPECIFIC_PASSWORD}" ]]; then
  if [[ -z "${APPLE_ID}" || -z "${APP_SPECIFIC_PASSWORD}" || -z "${TEAM_ID}" ]]; then
    echo "Apple ID notarization requires SCREEN_TEXT_GRAB_APPLE_ID, SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD, and SCREEN_TEXT_GRAB_NOTARY_TEAM_ID." >&2
    exit 1
  fi

  authentication_mode="apple-id"
  submit_args+=(--apple-id "${APPLE_ID}" --password "${APP_SPECIFIC_PASSWORD}" --team-id "${TEAM_ID}")
else
  authentication_mode="xcode-account-session"
fi

SIGNATURE_INFO="$(codesign -dv --verbose=4 "${APP_PATH}" 2>&1)"
if ! echo "${SIGNATURE_INFO}" | grep -F "Developer ID Application" >/dev/null 2>&1; then
  echo "Notarization requires a Developer ID signed app." >&2
  exit 1
fi

run_notarytool_flow() {
  echo "==> Preparing notarization ZIP"
  rm -f "${ZIP_PATH}"
  ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

  echo "==> Submitting to Apple notarization service"
  xcrun notarytool submit "${ZIP_PATH}" \
    "${submit_args[@]}" \
    --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "${APP_PATH}"
  xcrun stapler validate "${APP_PATH}"
}

run_xcode_account_flow() {
  require_command xcodebuild

  if [[ ! -d "${ARCHIVE_PATH}" ]]; then
    echo "Xcode account notarization requires an archive at: ${ARCHIVE_PATH}" >&2
    exit 1
  fi

  if [[ "${XCODE_NOTARY_TIMEOUT_SECONDS}" -le 0 || "${XCODE_NOTARY_POLL_INTERVAL_SECONDS}" -le 0 ]]; then
    echo "Xcode notarization timeout and poll interval must be positive integers." >&2
    exit 1
  fi

  if [[ -z "${TEAM_ID}" ]]; then
    echo "Set SCREEN_TEXT_GRAB_NOTARY_TEAM_ID or SCREEN_TEXT_GRAB_TEAM_ID to your own Apple Developer Team ID before using Xcode-account notarization." >&2
    exit 1
  fi

  upload_export_path="${ROOT_DIR}/.build/notary-upload"
  upload_options_plist="${ROOT_DIR}/.build/notary-upload-options.plist"
  mkdir -p "${ROOT_DIR}/.build"

  cat > "${upload_options_plist}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

  echo "==> Uploading archive to Apple's notarization service via Xcode account"
  xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${upload_export_path}" \
    -exportOptionsPlist "${upload_options_plist}" \
    -allowProvisioningUpdates

  echo "==> Waiting for notarized export from Apple"
  deadline=$((SECONDS + XCODE_NOTARY_TIMEOUT_SECONDS))
  attempt=1

  while (( SECONDS < deadline )); do
    export_path="${ROOT_DIR}/.build/notarized-export-attempt-${attempt}"
    export_log="/tmp/ScreenTextGrab-notarized-export-${attempt}.log"

    if xcodebuild -exportNotarizedApp \
      -archivePath "${ARCHIVE_PATH}" \
      -exportPath "${export_path}" >"${export_log}" 2>&1; then
      notarized_app_path="${export_path}/ScreenTextGrab.app"
      if [[ ! -d "${notarized_app_path}" ]]; then
        echo "Notarized export completed but app bundle was not found at ${notarized_app_path}" >&2
        cat "${export_log}" >&2
        exit 1
      fi

      ditto "${notarized_app_path}" "${APP_PATH}"
      rm -f "${ZIP_PATH}"
      ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
      xcrun stapler validate "${APP_PATH}"
      return 0
    fi

    if rg -n "processing and not ready for distribution" "${export_log}" >/dev/null 2>&1; then
      attempt=$((attempt + 1))
      sleep "${XCODE_NOTARY_POLL_INTERVAL_SECONDS}"
      continue
    fi

    cat "${export_log}" >&2
    exit 1
  done

  echo "Timed out waiting for notarized export from Apple." >&2
  echo "Increase SCREEN_TEXT_GRAB_XCODE_NOTARY_TIMEOUT_SECONDS and rerun this script." >&2
  exit 1
}

if [[ "${authentication_mode}" == "xcode-account-session" ]]; then
  run_xcode_account_flow
else
  run_notarytool_flow
fi

echo "==> Notarization completed"
echo "Authentication: ${authentication_mode}"
