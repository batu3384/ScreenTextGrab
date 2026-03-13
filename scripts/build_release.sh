#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/ScreenTextGrab.xcodeproj"
SCHEME="ScreenTextGrab"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${ROOT_DIR}/.build/release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${DERIVED_DATA_PATH}/ScreenTextGrab.xcarchive}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
EXPORT_DIR="${EXPORT_DIR:-${DIST_DIR}/export}"
APP_PATH="${DIST_DIR}/ScreenTextGrab.app"
ZIP_PATH="${DIST_DIR}/ScreenTextGrab.zip"
TEAM_ID="${SCREEN_TEXT_GRAB_TEAM_ID:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command xcodegen
require_command xcodebuild
require_command codesign
require_command security
require_command ditto
require_command openssl

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

if [[ -z "${TEAM_ID}" ]]; then
  echo "Set SCREEN_TEXT_GRAB_TEAM_ID to your own Apple Developer Team ID before creating a signed public release." >&2
  exit 1
fi

echo "==> Using Apple Developer Team ID: ${TEAM_ID}"

echo "==> Generating Xcode project"
xcodegen generate --spec "${ROOT_DIR}/project.yml"

echo "==> Cleaning old release outputs"
rm -rf "${ARCHIVE_PATH}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

EXPORT_OPTIONS_PLIST="$(mktemp "${TMPDIR:-/tmp}/ScreenTextGrabExportOptions.XXXXXX.plist")"
trap 'rm -f "${EXPORT_OPTIONS_PLIST}"' EXIT

cat > "${EXPORT_OPTIONS_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

echo "==> Archiving release"
xcodebuild archive \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  -allowProvisioningUpdates

echo "==> Exporting Developer ID package"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  -allowProvisioningUpdates

echo "==> Copying app bundle"
ditto "${EXPORT_DIR}/ScreenTextGrab.app" "${APP_PATH}"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

SIGNATURE_INFO="$(codesign -dv --verbose=4 "${APP_PATH}" 2>&1)"
echo "${SIGNATURE_INFO}" | sed -n '1,20p'

if ! echo "${SIGNATURE_INFO}" | grep -F "Developer ID Application" >/dev/null 2>&1; then
  echo "Release bundle is not signed with a Developer ID Application identity." >&2
  exit 1
fi

echo "==> Building ZIP package"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "==> Release bundle ready"
echo "App: ${APP_PATH}"
echo "ZIP: ${ZIP_PATH}"
