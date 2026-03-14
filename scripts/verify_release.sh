#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-/Applications/ScreenTextGrab.app}"
VERIFY_MODE="${VERIFY_MODE:-public}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command codesign
require_command spctl
require_command xcrun
require_command /usr/libexec/PlistBuddy

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found: ${APP_PATH}" >&2
  exit 1
fi

APP_DIR="$(cd "$(dirname "${APP_PATH}")" && pwd -P)"
APP_PATH="${APP_DIR}/$(basename "${APP_PATH}")"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"

read_plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

echo "==> Version metadata"
read_plist_value "${INFO_PLIST}" CFBundleShortVersionString
read_plist_value "${INFO_PLIST}" CFBundleVersion

echo "==> Code signature"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
SIGNATURE_INFO="$(codesign -dv --verbose=4 "${APP_PATH}" 2>&1)"
echo "${SIGNATURE_INFO}" | sed -n '1,20p'

echo "==> Entitlement hygiene"
ENTITLEMENTS="$(codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null || true)"
if echo "${ENTITLEMENTS}" | grep -F "com.apple.security.get-task-allow" >/dev/null 2>&1; then
  echo "Unexpected development entitlement found: com.apple.security.get-task-allow" >&2
  exit 1
fi

if [[ "${VERIFY_MODE}" == "public" ]]; then
  if ! echo "${SIGNATURE_INFO}" | grep -F "Authority=Developer ID Application" >/dev/null 2>&1; then
    echo "Public verification requires a Developer ID Application signature." >&2
    echo "Current signing authority:" >&2
    echo "${SIGNATURE_INFO}" | grep -F "Authority=" >&2
    exit 1
  fi

  echo "==> Gatekeeper"
  spctl -a -vv "${APP_PATH}"

  echo "==> Notarization ticket"
  xcrun stapler validate "${APP_PATH}"
else
  echo "==> Gatekeeper"
  echo "Skipping Gatekeeper/notarization checks in local mode"
fi

echo "==> Permission scope"
if /usr/libexec/PlistBuddy -c "Print :NSAppleEventsUsageDescription" "${INFO_PLIST}" >/dev/null 2>&1; then
  echo "Unexpected Apple Events permission present in release bundle" >&2
  exit 1
fi
read_plist_value "${INFO_PLIST}" NSScreenCaptureUsageDescription
