#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_SLUG="${SCREEN_TEXT_GRAB_REPOSITORY:-batu3384/ScreenTextGrab}"
ASSET_NAME="${SCREEN_TEXT_GRAB_RELEASE_ASSET:-ScreenTextGrab.zip}"
DOWNLOAD_URL="https://github.com/${REPO_SLUG}/releases/latest/download/${ASSET_NAME}"
INSTALL_PATH="/Applications/ScreenTextGrab.app"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ScreenTextGrab-release-install.XXXXXX")"
ZIP_PATH="${TMP_DIR}/${ASSET_NAME}"
EXTRACT_DIR="${TMP_DIR}/extract"
RESET_SCREEN_CAPTURE=false
LAUNCH_AFTER_INSTALL=true

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: scripts/install_release.sh [--reset-screen-capture] [--no-launch]

Downloads the latest GitHub release of ScreenTextGrab, installs it into
/Applications, removes stale copies, and optionally launches the app.
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

require_command curl
require_command ditto

echo "==> Downloading latest ScreenTextGrab release"
if ! curl --fail --location --silent --show-error "${DOWNLOAD_URL}" --output "${ZIP_PATH}"; then
  cat >&2 <<EOF
Failed to download the latest release asset:
${DOWNLOAD_URL}

If you are installing from a local clone instead, run:
  ./scripts/install.sh --source
EOF
  exit 1
fi

mkdir -p "${EXTRACT_DIR}"

echo "==> Extracting app bundle"
ditto -x -k "${ZIP_PATH}" "${EXTRACT_DIR}"

if [[ ! -d "${EXTRACT_DIR}/ScreenTextGrab.app" ]]; then
  echo "Release archive did not contain ScreenTextGrab.app" >&2
  exit 1
fi

echo "==> Installing canonical app copy"
rm -rf "${INSTALL_PATH}"
ditto "${EXTRACT_DIR}/ScreenTextGrab.app" "${INSTALL_PATH}"

echo "==> Cleaning stale app copies"
"${ROOT_DIR}/scripts/cleanup_app_copies.sh" $([[ "${RESET_SCREEN_CAPTURE}" == "true" ]] && printf '%s' "--reset-tcc")

if [[ "${LAUNCH_AFTER_INSTALL}" == "true" ]]; then
  echo "==> Launching ${INSTALL_PATH}"
  open "${INSTALL_PATH}"
fi
