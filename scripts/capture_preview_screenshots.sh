#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ScreenTextGrab.xcodeproj"
SCHEME="ScreenTextGrab"
DERIVED_DATA_PATH="$(mktemp -d "${TMPDIR%/}/ScreenTextGrab-preview-screenshots.XXXXXX")"
OUTPUT_DIR="$ROOT_DIR/docs/screenshots"

modes=(
  "menu-panel:--screenshot-menu-panel"
  "settings-general:--screenshot-settings-general"
  "settings-ocr:--screenshot-settings-ocr"
  "settings-history:--screenshot-settings-history"
  "settings-diagnostics:--screenshot-settings-diagnostics"
  "table-review:--screenshot-table-review"
)

build_app() {
  xcodebuild build \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    >/tmp/screentextgrab-preview-build.log
}

app_path() {
  printf "%s\n" "$DERIVED_DATA_PATH/Build/Products/Debug/ScreenTextGrab.app"
}

window_id_for_pid() {
  local pid="$1"
  /usr/bin/swift -e '
import CoreGraphics
import Foundation

let pid = Int32(CommandLine.arguments[1])!
let deadline = Date().addingTimeInterval(12)

func area(of bounds: [String: Any]) -> CGFloat {
    let width = bounds["Width"] as? CGFloat ?? 0
    let height = bounds["Height"] as? CGFloat ?? 0
    return width * height
}

while Date() < deadline {
    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let candidates = windowList.filter { window in
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
              ownerPID == pid,
              let layer = window[kCGWindowLayer as String] as? Int,
              layer == 0 else {
            return false
        }

        let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
        let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
        return alpha > 0 && area(of: bounds) > 1000
    }
    .sorted { lhs, rhs in
        let lhsArea = area(of: lhs[kCGWindowBounds as String] as? [String: Any] ?? [:])
        let rhsArea = area(of: rhs[kCGWindowBounds as String] as? [String: Any] ?? [:])
        return lhsArea > rhsArea
    }

    if let window = candidates.first,
       let windowNumber = window[kCGWindowNumber as String] as? Int {
        print(windowNumber)
        exit(0)
    }

    Thread.sleep(forTimeInterval: 0.2)
}

exit(1)
' "$pid"
}

capture_mode() {
  local name="$1"
  local argument="$2"
  local output_path="$OUTPUT_DIR/$name.png"
  local pid=""

  SCREENTEXTGRAB_UI_LANGUAGE=en \
    "$(app_path)/Contents/MacOS/ScreenTextGrab" "$argument" >/tmp/"$name".log 2>&1 &
  pid=$!

  cleanup() {
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
    fi
  }
  trap cleanup RETURN

  local window_id
  window_id="$(window_id_for_pid "$pid")"

  /usr/sbin/screencapture -x -l "$window_id" "$output_path"
  sleep 0.2
}

main() {
  cleanup_derived_data() {
    rm -rf "$DERIVED_DATA_PATH"
  }
  trap cleanup_derived_data EXIT

  mkdir -p "$OUTPUT_DIR"
  build_app

  for mode in "${modes[@]}"; do
    local_name="${mode%%:*}"
    local_argument="${mode#*:}"
    printf "Capturing %s...\n" "$local_name"
    capture_mode "$local_name" "$local_argument"
  done

  printf "Saved screenshots to %s\n" "$OUTPUT_DIR"
}

main "$@"
