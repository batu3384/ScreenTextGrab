#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${SCREEN_TEXT_GRAB_REPOSITORY:-batu3384/ScreenTextGrab}"
REF="${SCREEN_TEXT_GRAB_REF:-main}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ScreenTextGrab-bootstrap.XXXXXX")"
ARCHIVE_PATH="${TMP_DIR}/source.tar.gz"
MODE="auto"
COMMON_ARGS=()
SOURCE_ONLY_ARGS=()

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap_install.sh [--auto|--source|--release] [--reset-screen-capture] [--no-launch] [--allow-adhoc]

Downloads ScreenTextGrab from GitHub and installs it with a single command.

Modes:
  --auto     Use the latest release if available, otherwise fall back to source install (default)
  --source   Force a local build from the downloaded source snapshot
  --release  Force installation from the latest GitHub release asset
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)
      MODE="auto"
      shift
      ;;
    --source)
      MODE="source"
      shift
      ;;
    --release)
      MODE="release"
      shift
      ;;
    --reset-screen-capture|--no-launch|--allow-adhoc)
      if [[ "$1" == "--allow-adhoc" ]]; then
        SOURCE_ONLY_ARGS+=("$1")
      else
        COMMON_ARGS+=("$1")
      fi
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

release_asset_exists() {
  local url="https://github.com/${REPO_SLUG}/releases/latest/download/ScreenTextGrab.zip"
  local code
  code="$(curl -I -L -s -o /dev/null -w '%{http_code}' "${url}")"
  [[ "${code}" == "200" ]]
}

require_command curl
require_command tar

INSTALL_MODE="${MODE}"
if [[ "${INSTALL_MODE}" == "auto" ]]; then
  if [[ ${#SOURCE_ONLY_ARGS[@]} -gt 0 ]]; then
    INSTALL_MODE="source"
  elif release_asset_exists; then
    INSTALL_MODE="release"
  else
    INSTALL_MODE="source"
  fi
fi

echo "==> Downloading ScreenTextGrab source snapshot (${REF})"
curl --fail --location --silent --show-error \
  "https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REF}" \
  --output "${ARCHIVE_PATH}"

echo "==> Extracting source snapshot"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

SOURCE_DIR="$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${SOURCE_DIR}" || ! -d "${SOURCE_DIR}/scripts" ]]; then
  echo "Downloaded archive does not contain the expected ScreenTextGrab scripts directory." >&2
  exit 1
fi

echo "==> Selected install mode: ${INSTALL_MODE}"
if [[ "${INSTALL_MODE}" == "release" && ${#SOURCE_ONLY_ARGS[@]} -gt 0 ]]; then
  echo "--allow-adhoc is only supported with source installs." >&2
  exit 1
fi

INSTALL_CMD=("${SOURCE_DIR}/scripts/install.sh" "--${INSTALL_MODE}")
if [[ ${#COMMON_ARGS[@]} -gt 0 ]]; then
  INSTALL_CMD+=("${COMMON_ARGS[@]}")
fi
if [[ ${#SOURCE_ONLY_ARGS[@]} -gt 0 ]]; then
  INSTALL_CMD+=("${SOURCE_ONLY_ARGS[@]}")
fi

exec "${INSTALL_CMD[@]}"
