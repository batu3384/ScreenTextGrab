#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command rg
require_command find
require_command git

echo "==> Checking ignored junk files"
junk_files="$(find . \
  \( -name '.DS_Store' -o -name '*.profraw' -o -name '*.xcuserstate' \) \
  -not -path './.git/*' \
  -print)"

if [[ -n "${junk_files}" ]]; then
  printf 'Unexpected junk files:\n' >&2
  printf '%s\n' "${junk_files}" | sed 's/^/  /' >&2
  exit 1
fi

echo "==> Checking forbidden plist permissions"
if rg -n "NSAppleEventsUsageDescription" ScreenTextGrab/Info.plist >/dev/null 2>&1; then
  echo "Unexpected Apple Events permission found in Info.plist" >&2
  exit 1
fi

echo "==> Checking for hardcoded secrets"
secret_pattern='BEGIN (RSA|EC|OPENSSH|DSA) PRIVATE KEY|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|sk_(live|proj|test)?[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN PRIVATE KEY-----'
if rg -n --hidden --glob '!.git/*' --glob '!scripts/repo_audit.sh' --glob '!*.png' --glob '!*.icns' --glob '!*.pdf' "${secret_pattern}" . >/dev/null 2>&1; then
  echo "Possible secret material detected in repository files" >&2
  rg -n --hidden --glob '!.git/*' --glob '!scripts/repo_audit.sh' --glob '!*.png' --glob '!*.icns' --glob '!*.pdf' "${secret_pattern}" .
  exit 1
fi

echo "==> Checking for hardcoded team identifiers"
team_identifier_pattern='DEVELOPMENT_TEAM[[:space:]]*[:=][[:space:]]*[A-Z0-9]{10}|SCREEN_TEXT_GRAB_(NOTARY_)?TEAM_ID:-[A-Z0-9]{10}|<key>teamID</key>[[:space:]]*<string>[A-Z0-9]{10}</string>'
if rg -n --multiline --hidden --glob '!.git/*' --glob '!scripts/repo_audit.sh' --glob '!*.png' --glob '!*.icns' --glob '!*.pdf' "${team_identifier_pattern}" . >/dev/null 2>&1; then
  echo "Hardcoded Apple Developer team identifier detected in repository files" >&2
  rg -n --multiline --hidden --glob '!.git/*' --glob '!scripts/repo_audit.sh' --glob '!*.png' --glob '!*.icns' --glob '!*.pdf' "${team_identifier_pattern}" .
  exit 1
fi

echo "==> Checking for leaked local user paths"
local_path_pattern='/Users/[A-Za-z0-9._-]+/'
local_path_hits="$(rg -n --hidden --glob '!.git/*' --glob '!scripts/repo_audit.sh' --glob '!*.png' --glob '!*.icns' --glob '!*.pdf' "${local_path_pattern}" . | rg -v '/Users/example/' || true)"
if [[ -n "${local_path_hits}" ]]; then
  echo "Local absolute user paths detected in repository files" >&2
  printf '%s\n' "${local_path_hits}" >&2
  exit 1
fi

echo "==> Checking required repository files"
required_files=(
  ".gitignore"
  "README.md"
  "SECURITY.md"
  ".github/workflows/ci.yml"
  "project.yml"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Missing required repository file: ${required_file}" >&2
    exit 1
  fi
done

echo "==> Checking disallowed repository helper files"
disallowed_repo_files="$(git ls-files --cached --others --exclude-standard -- \
  COMMIT_MESSAGE.txt \
  PR_DESCRIPTION.md \
  CLAUDE.md)"

if [[ -n "${disallowed_repo_files}" ]]; then
  printf 'Disallowed repository helper files found:\n' >&2
  printf '%s\n' "${disallowed_repo_files}" | sed 's/^/  /' >&2
  exit 1
fi

echo "Repository audit passed"
