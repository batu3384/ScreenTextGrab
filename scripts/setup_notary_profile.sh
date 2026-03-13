#!/usr/bin/env bash
set -euo pipefail

PROFILE_NAME="${SCREEN_TEXT_GRAB_NOTARY_PROFILE:-ScreenTextGrab-Notary}"
APPLE_ID="${SCREEN_TEXT_GRAB_APPLE_ID:-}"
APP_SPECIFIC_PASSWORD="${SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD:-}"
TEAM_ID="${SCREEN_TEXT_GRAB_NOTARY_TEAM_ID:-${SCREEN_TEXT_GRAB_TEAM_ID:-}}"
ASC_KEY_PATH="${SCREEN_TEXT_GRAB_ASC_KEY_PATH:-}"
ASC_KEY_ID="${SCREEN_TEXT_GRAB_ASC_KEY_ID:-}"
ASC_ISSUER_ID="${SCREEN_TEXT_GRAB_ASC_ISSUER_ID:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command xcrun

store_args=()
mode=""

if [[ -n "${ASC_KEY_PATH}" || -n "${ASC_KEY_ID}" || -n "${ASC_ISSUER_ID}" ]]; then
  if [[ -z "${ASC_KEY_PATH}" || -z "${ASC_KEY_ID}" ]]; then
    echo "App Store Connect profile setup requires SCREEN_TEXT_GRAB_ASC_KEY_PATH and SCREEN_TEXT_GRAB_ASC_KEY_ID." >&2
    exit 1
  fi

  mode="app-store-connect-api-key"
  store_args+=(--key "${ASC_KEY_PATH}" --key-id "${ASC_KEY_ID}")
  if [[ -n "${ASC_ISSUER_ID}" ]]; then
    store_args+=(--issuer "${ASC_ISSUER_ID}")
  fi
elif [[ -n "${APPLE_ID}" || -n "${APP_SPECIFIC_PASSWORD}" ]]; then
  if [[ -z "${APPLE_ID}" || -z "${APP_SPECIFIC_PASSWORD}" || -z "${TEAM_ID}" ]]; then
    echo "Apple ID profile setup requires SCREEN_TEXT_GRAB_APPLE_ID, SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD, and SCREEN_TEXT_GRAB_NOTARY_TEAM_ID." >&2
    exit 1
  fi

  mode="apple-id"
  store_args+=(--apple-id "${APPLE_ID}" --password "${APP_SPECIFIC_PASSWORD}" --team-id "${TEAM_ID}")
else
  echo "Provide notarization credentials before creating a keychain profile." >&2
  echo "Supported options:" >&2
  echo "  1) SCREEN_TEXT_GRAB_APPLE_ID + SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD + SCREEN_TEXT_GRAB_NOTARY_TEAM_ID" >&2
  echo "  2) SCREEN_TEXT_GRAB_ASC_KEY_PATH + SCREEN_TEXT_GRAB_ASC_KEY_ID (+ SCREEN_TEXT_GRAB_ASC_ISSUER_ID for team keys)" >&2
  exit 1
fi

echo "==> Storing notarization credentials in keychain profile: ${PROFILE_NAME}"
xcrun notarytool store-credentials "${PROFILE_NAME}" \
  "${store_args[@]}" \
  --validate

echo "==> Notary profile ready"
echo "Profile: ${PROFILE_NAME}"
echo "Authentication: ${mode}"
