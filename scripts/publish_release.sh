#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
ZIP_PATH="${ZIP_PATH:-${DIST_DIR}/ScreenTextGrab.zip}"
NOTES_FILE="${NOTES_FILE:-${ROOT_DIR}/RELEASE_NOTES.md}"
TITLE=""
DRAFT=false
PRERELEASE=false
SKIP_BUILD=false
SKIP_NOTARIZE=false
SKIP_VERIFY=false
TAG=""

usage() {
  cat <<'EOF'
Usage: scripts/publish_release.sh <tag> [options]

Builds ScreenTextGrab, optionally notarizes it, verifies the result, and
publishes or updates a GitHub release with dist/ScreenTextGrab.zip.

Options:
  --title <title>       Release title (default: "ScreenTextGrab <tag>")
  --notes-file <path>   Release notes markdown file (default: RELEASE_NOTES.md)
  --draft               Create/update the release as draft
  --prerelease          Mark the release as prerelease
  --skip-build          Skip build_release.sh and reuse existing dist artifacts
  --skip-notarize       Skip notarize_release.sh
  --skip-verify         Skip verify_release.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --draft)
      DRAFT=true
      shift
      ;;
    --prerelease)
      PRERELEASE=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=true
      shift
      ;;
    --skip-verify)
      SKIP_VERIFY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "${TAG}" ]]; then
        TAG="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command gh

if [[ -z "${TAG}" ]]; then
  echo "Release tag is required." >&2
  usage >&2
  exit 1
fi

if [[ -z "${TITLE}" ]]; then
  TITLE="ScreenTextGrab ${TAG}"
fi

if [[ ! -f "${NOTES_FILE}" ]]; then
  echo "Release notes file not found: ${NOTES_FILE}" >&2
  exit 1
fi

if [[ "${SKIP_BUILD}" != "true" ]]; then
  "${ROOT_DIR}/scripts/build_release.sh"
fi

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "Release ZIP not found: ${ZIP_PATH}" >&2
  exit 1
fi

if [[ "${SKIP_NOTARIZE}" != "true" ]]; then
  "${ROOT_DIR}/scripts/notarize_release.sh"
fi

if [[ "${SKIP_VERIFY}" != "true" ]]; then
  if [[ "${SKIP_NOTARIZE}" == "true" ]]; then
    VERIFY_MODE=local APP_PATH="${DIST_DIR}/ScreenTextGrab.app" "${ROOT_DIR}/scripts/verify_release.sh"
  else
    APP_PATH="${DIST_DIR}/ScreenTextGrab.app" "${ROOT_DIR}/scripts/verify_release.sh"
  fi
fi

release_args=()
if [[ "${DRAFT}" == "true" ]]; then
  release_args+=(--draft)
else
  release_args+=(--draft=false)
fi
if [[ "${PRERELEASE}" == "true" ]]; then
  release_args+=(--prerelease)
fi

if gh release view "${TAG}" >/dev/null 2>&1; then
  gh release edit "${TAG}" \
    --title "${TITLE}" \
    --notes-file "${NOTES_FILE}" \
    "${release_args[@]}"
  gh release upload "${TAG}" "${ZIP_PATH}" --clobber
else
  gh release create "${TAG}" "${ZIP_PATH}" \
    --title "${TITLE}" \
    --notes-file "${NOTES_FILE}" \
    "${release_args[@]}"
fi

echo "==> GitHub release published"
echo "Tag: ${TAG}"
