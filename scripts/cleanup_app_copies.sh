#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ScreenTextGrab.app"
BUNDLE_ID="${SCREEN_TEXT_GRAB_BUNDLE_ID:-dev.screentextgrab.app}"
CANONICAL_PATH="/Applications/${APP_NAME}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESET_TCC=false

if [[ "${1:-}" == "--reset-tcc" ]]; then
  RESET_TCC=true
fi

echo "==> Terminating running ScreenTextGrab processes"
pkill -f "/${APP_NAME}/Contents/MacOS/ScreenTextGrab" 2>/dev/null || true
sleep 1

echo "==> Discovering app copies"
REMOVED=0

remove_app_path() {
  local path="$1"
  if [[ ! -d "$path" || "$path" == "$CANONICAL_PATH" ]]; then
    return
  fi

  echo "Removing: $path"
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$path" >/dev/null 2>&1 || true
  rm -rf "$path"
  REMOVED=$((REMOVED + 1))
}

remove_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    return
  fi

  echo "Removing artifact: $path"
  rm -rf "$path"
  REMOVED=$((REMOVED + 1))
}

unregister_app_path() {
  local path="$1"
  if [[ ! -d "$path" || "$path" == "$CANONICAL_PATH" ]]; then
    return
  fi

  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$path" >/dev/null 2>&1 || true
}

remove_app_path "$HOME/Applications/${APP_NAME}"
remove_app_path "$HOME/Desktop/${APP_NAME}"
remove_app_path "$HOME/Downloads/${APP_NAME}"

while IFS= read -r path; do
  remove_app_path "$path"
done < <(find /Applications -maxdepth 1 -type d -iname 'ScreenTextGrab.app*' 2>/dev/null | sort -u)

while IFS= read -r path; do
  remove_app_path "$path"
done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name "${APP_NAME}" 2>/dev/null | sort -u)

while IFS= read -r path; do
  remove_app_path "$path"
done < <(find /private/tmp -maxdepth 3 -type d -name "${APP_NAME}" 2>/dev/null | sort -u)

while IFS= read -r path; do
  remove_path "$path"
done < <(find /private/tmp -maxdepth 1 -iname 'ScreenTextGrab*' 2>/dev/null | sort -u)

remove_path "${REPO_ROOT}/dist"
remove_path "${REPO_ROOT}/.build/release"
remove_path "${REPO_ROOT}/.build/local-install"

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  [[ "$path" == "$CANONICAL_PATH" ]] && continue
  unregister_app_path "$path"

  case "$path" in
    */DerivedData/*|*/.build/*|*/dist/*|/private/tmp/*|/tmp/*)
      remove_app_path "$path"
      ;;
  esac
done < <(mdfind "kMDItemFSName == '${APP_NAME}'" | sort -u)

if [[ "$RESET_TCC" == "true" ]]; then
  echo "==> Resetting TCC ScreenCapture entry for ${BUNDLE_ID}"
  tccutil reset ScreenCapture "${BUNDLE_ID}" || true
fi

echo "==> Rebuilding Launch Services database"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -kill -r -domain local -domain system -domain user >/dev/null 2>&1 || true

echo "==> Re-registering canonical app"
if [[ -d "$CANONICAL_PATH" ]]; then
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$CANONICAL_PATH" >/dev/null 2>&1 || true
else
  echo "WARNING: ${CANONICAL_PATH} not found"
fi

echo "==> Remaining indexed copies"
mdfind "kMDItemFSName == '${APP_NAME}'" | sed -n '1,50p'
echo "Removed copies: ${REMOVED}"
