#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [--source|--release] [--reset-screen-capture] [--no-launch] [--allow-adhoc]

Installs ScreenTextGrab into /Applications so Spotlight can find and launch it.

Modes:
  --source   Build from the local repository and install the app (default)
  --release  Download the latest GitHub release asset and install it

Options:
  --reset-screen-capture  Reset macOS Screen Recording approval for the app bundle id
  --no-launch             Install without launching the app afterward
  --allow-adhoc           Allow ad-hoc signing when building from source
EOF
}

MODE="source"
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      MODE="source"
      shift
      ;;
    --release)
      MODE="release"
      shift
      ;;
    --reset-screen-capture|--no-launch|--allow-adhoc)
      ARGS+=("$1")
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

case "${MODE}" in
  source)
    exec "${ROOT_DIR}/scripts/install_local_app.sh" "${ARGS[@]}"
    ;;
  release)
    exec "${ROOT_DIR}/scripts/install_release.sh" "${ARGS[@]}"
    ;;
esac
