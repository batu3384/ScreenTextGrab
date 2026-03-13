#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/ScreenTextGrab.xcodeproj"
SCHEME="ScreenTextGrab"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${ROOT_DIR}/.build/local-install}"
BUILD_APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/ScreenTextGrab.app"
INSTALL_PATH="/Applications/ScreenTextGrab.app"
BUNDLE_ID="${SCREEN_TEXT_GRAB_BUNDLE_ID:-dev.screentextgrab.app}"
SIGN_IDENTITY="${SCREEN_TEXT_GRAB_LOCAL_SIGN_IDENTITY:-}"
RESET_SCREEN_CAPTURE=false
LAUNCH_AFTER_INSTALL=true
ALLOW_ADHOC=false

usage() {
  cat <<'EOF'
Usage: scripts/install_local_app.sh [--reset-screen-capture] [--no-launch] [--allow-adhoc]

Builds the app locally, installs it into /Applications, signs it with the
first available Apple Development identity, cleans old app copies, and
optionally launches the canonical app.

If no local signing identity exists, the script fails by default because
ad-hoc signed installs do not provide stable Screen Recording permissions.
Use --allow-adhoc only for temporary development builds.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset-screen-capture)
      RESET_SCREEN_CAPTURE=true
      shift
      ;;
    --no-launch)
      LAUNCH_AFTER_INSTALL=false
      shift
      ;;
    --allow-adhoc)
      ALLOW_ADHOC=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

detect_sign_identity() {
  if [[ -n "${SIGN_IDENTITY}" ]]; then
    printf '%s\n' "${SIGN_IDENTITY}"
    return
  fi

  local identity
  identity="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)"/\1/p' | head -n 1)"
  if [[ -n "${identity}" ]]; then
    printf '%s\n' "${identity}"
    return
  fi

  identity="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Mac Developer:[^"]*\)"/\1/p' | head -n 1)"
  printf '%s\n' "${identity}"
}

require_command xcodebuild
require_command codesign
require_command security
require_command ditto

echo "==> Building local release bundle"
xcodebuild build \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "${BUILD_APP_PATH}" ]]; then
  echo "Build output not found: ${BUILD_APP_PATH}" >&2
  exit 1
fi

echo "==> Installing canonical app copy"
rm -rf "${INSTALL_PATH}"
ditto "${BUILD_APP_PATH}" "${INSTALL_PATH}"

SIGN_IDENTITY="$(detect_sign_identity)"
if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "==> Signing with local identity: ${SIGN_IDENTITY}"
  codesign --force --deep --sign "${SIGN_IDENTITY}" "${INSTALL_PATH}"
else
  if [[ "${ALLOW_ADHOC}" != "true" ]]; then
    cat >&2 <<EOF
No Apple Development signing identity was found.
Refusing to install an ad-hoc signed copy because Screen Recording permissions
will not attach reliably to that app.

Create/import a local Apple Development certificate or rerun with --allow-adhoc
for a temporary development-only install.
EOF
    exit 1
  fi

  echo "==> WARNING: no Apple Development identity found; using ad-hoc signing by explicit request" >&2
  codesign --force --deep --sign - "${INSTALL_PATH}"
fi

echo "==> Verifying signature"
codesign --verify --deep --strict "${INSTALL_PATH}"
codesign -dv --verbose=4 "${INSTALL_PATH}" 2>&1 | sed -n '1,20p'

if [[ "${RESET_SCREEN_CAPTURE}" == "true" ]]; then
  echo "==> Resetting ScreenCapture approval for ${BUNDLE_ID}"
  tccutil reset ScreenCapture "${BUNDLE_ID}" || true
fi

echo "==> Cleaning stale app copies"
"${ROOT_DIR}/scripts/cleanup_app_copies.sh"

if [[ "${LAUNCH_AFTER_INSTALL}" == "true" ]]; then
  echo "==> Launching ${INSTALL_PATH}"
  open "${INSTALL_PATH}"
fi
