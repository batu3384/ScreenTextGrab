#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_SOURCE="${ROOT_DIR}/scripts/stg"
CLI_NAME="stg"
DESTINATION_OVERRIDE="${SCREEN_TEXT_GRAB_CLI_DIR:-}"

usage() {
  cat <<'EOF'
Usage: scripts/install_cli_command.sh

Installs the ScreenTextGrab command-line helper as `stg`.

Environment:
  SCREEN_TEXT_GRAB_CLI_DIR  Optional install directory override.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

is_in_path() {
  local dir="$1"
  local normalized_path=":${PATH}:"
  [[ "${normalized_path}" == *":${dir}:"* ]]
}

ensure_dir() {
  local dir="$1"
  if [[ -d "${dir}" ]]; then
    [[ -w "${dir}" ]]
    return
  fi

  local parent
  parent="$(dirname "${dir}")"
  [[ -w "${parent}" ]] || return 1
  mkdir -p "${dir}"
}

resolve_install_dir() {
  if [[ -n "${DESTINATION_OVERRIDE}" ]]; then
    ensure_dir "${DESTINATION_OVERRIDE}" || {
      echo "Unable to create CLI install directory: ${DESTINATION_OVERRIDE}" >&2
      return 1
    }
    printf '%s\n' "${DESTINATION_OVERRIDE}"
    return
  fi

  local preferred_dirs=(
    "/usr/local/bin"
    "/opt/homebrew/bin"
    "${HOME}/.local/bin"
    "${HOME}/bin"
  )

  local dir
  for dir in "${preferred_dirs[@]}"; do
    if is_in_path "${dir}" && ensure_dir "${dir}"; then
      printf '%s\n' "${dir}"
      return
    fi
  done

  for dir in "${preferred_dirs[@]}"; do
    if ensure_dir "${dir}"; then
      printf '%s\n' "${dir}"
      return
    fi
  done

  echo "Could not find a writable install directory for ${CLI_NAME}." >&2
  return 1
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_command install

  if [[ ! -f "${CLI_SOURCE}" ]]; then
    echo "CLI source not found: ${CLI_SOURCE}" >&2
    exit 1
  fi

  local install_dir
  install_dir="$(resolve_install_dir)"
  local destination="${install_dir}/${CLI_NAME}"

  install -m 755 "${CLI_SOURCE}" "${destination}"
  echo "Installed CLI command: ${destination}"

  if ! is_in_path "${install_dir}"; then
    echo "NOTE: ${install_dir} is not currently in PATH." >&2
    echo "Add it to your shell profile to use '${CLI_NAME}' without a full path." >&2
  fi
}

main "$@"
