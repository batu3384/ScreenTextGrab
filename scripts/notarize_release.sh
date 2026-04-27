#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
DIST_APP_DIR="${DIST_APP_DIR:-${DIST_DIR}/.app-bundles.noindex}"
APP_PATH="${APP_PATH:-${DIST_APP_DIR}/ScreenTextGrab.app}"
NOTARY_ZIP_PATH="${ZIP_PATH:-${DIST_DIR}/ScreenTextGrab-notarization.zip}"
PUBLIC_ZIP_PATH="${PUBLIC_ZIP_PATH:-${DIST_DIR}/ScreenTextGrab.zip}"
CHECKSUM_PATH="${CHECKSUM_PATH:-${PUBLIC_ZIP_PATH}.sha256}"
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
require_command openssl
require_command shasum

detect_team_id() {
  local certificate_pem=""
  local subject=""
  local team_id=""
  local keychains=("$HOME/Library/Keychains/login.keychain-db" "/Library/Keychains/System.keychain")

  certificate_pem="$(security find-certificate -a -c "Developer ID Application" -p "${keychains[@]}" 2>/dev/null || true)"
  if [[ -z "${certificate_pem}" ]]; then
    certificate_pem="$(security find-certificate -a -c "Apple Development" -p "${keychains[@]}" 2>/dev/null || true)"
  fi

  if [[ -z "${certificate_pem}" ]]; then
    return 1
  fi

  subject="$(printf '%s\n' "${certificate_pem}" | openssl x509 -noout -subject 2>/dev/null || true)"
  team_id="$(printf '%s\n' "${subject}" | sed -nE 's/.*OU=([^,\\/]+).*/\1/p' | head -n 1)"

  if [[ -z "${team_id}" ]]; then
    return 1
  fi

  printf '%s\n' "${team_id}"
}

if [[ -z "${TEAM_ID}" ]]; then
  TEAM_ID="$(detect_team_id || true)"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Release app not found: ${APP_PATH}" >&2
  exit 1
fi

APP_DIR="$(cd "$(dirname "${APP_PATH}")" && pwd -P)"
APP_PATH="${APP_DIR}/$(basename "${APP_PATH}")"
NOTARY_ZIP_DIR="$(cd "$(dirname "${NOTARY_ZIP_PATH}")" && pwd -P)"
NOTARY_ZIP_PATH="${NOTARY_ZIP_DIR}/$(basename "${NOTARY_ZIP_PATH}")"
PUBLIC_ZIP_DIR="$(cd "$(dirname "${PUBLIC_ZIP_PATH}")" && pwd -P)"
PUBLIC_ZIP_PATH="${PUBLIC_ZIP_DIR}/$(basename "${PUBLIC_ZIP_PATH}")"
CHECKSUM_DIR="$(cd "$(dirname "${CHECKSUM_PATH}")" && pwd -P)"
CHECKSUM_PATH="${CHECKSUM_DIR}/$(basename "${CHECKSUM_PATH}")"
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

rebuild_public_zip() {
  echo "==> Rebuilding public ZIP from notarized app"
  rm -f "${PUBLIC_ZIP_PATH}" "${CHECKSUM_PATH}"
  ditto -c -k --keepParent "${APP_PATH}" "${PUBLIC_ZIP_PATH}"
  (
    cd "$(dirname "${PUBLIC_ZIP_PATH}")"
    shasum -a 256 "$(basename "${PUBLIC_ZIP_PATH}")"
  ) > "${CHECKSUM_PATH}"
}

run_notarytool_flow() {
  echo "==> Preparing notarization ZIP"
  rm -f "${NOTARY_ZIP_PATH}"
  ditto -c -k --keepParent "${APP_PATH}" "${NOTARY_ZIP_PATH}"

  echo "==> Submitting to Apple notarization service"
  xcrun notarytool submit "${NOTARY_ZIP_PATH}" \
    "${submit_args[@]}" \
    --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "${APP_PATH}"
  xcrun stapler validate "${APP_PATH}"
  rebuild_public_zip
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
  rm -rf "${upload_export_path}"

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
    rm -rf "${export_path}"

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
      xcrun stapler validate "${APP_PATH}"
      rebuild_public_zip
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
echo "ZIP: ${PUBLIC_ZIP_PATH}"
echo "SHA-256: ${CHECKSUM_PATH}"
