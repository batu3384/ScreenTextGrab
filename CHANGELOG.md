# Changelog

All notable changes to ScreenTextGrab are documented in this file.

## 1.0.1 - 2026-03-09

### Added
- User-configurable global hotkey with persistence and reset to default.
- Launch-at-login toggle backed by `SMAppService`.
- OCR language preferences with automatic language detection support.
- Multiple capture modes: Standard, Subtitle, Code, and Table.
- QR and barcode fallback when OCR is weak or empty.
- Watch mode for repeated OCR on a selected region.
- Smart actions for captured content such as open link, compose mail, call number, web search, translate, and text-to-speech.
- Searchable persisted capture history with export support.
- UI test target and launch-panel UI coverage.
- Repository audit, CI workflow, release build, notarization, verification, and cleanup scripts.

### Improved
- Menu bar interface was compacted and reworked for clearer controls and smaller-screen behavior.
- App icon set, menu bar icon, and visual theme were refreshed for a more coherent product identity.
- Launch/onboarding flow now distinguishes foreground launch from background/login launch.
- Screen Recording permission checks now use passive verification before prompting the user.
- Capture pipeline behavior is mode-aware, including subtitle-focused OCR and code/table-specific formatting.
- Installed-app detection now handles both `/Applications` and `~/Applications`.

### Fixed
- Repeated Screen Recording permission prompts after the user had already granted access.
- Incorrect permission-state reporting in the app surface.
- Launch-at-login state mismatches and stale registration edge cases.
- Global hotkey registration silently failing without clear feedback.
- Menu panel overflow and unreadable capture-mode controls.
- Watch mode race where OCR work could finish after the user stopped watching.
- Missing or inconsistent app icon metadata in installed builds.
- Release builds incorrectly carrying development entitlements.

### Developer Experience
- Added GitHub repository hygiene files and security documentation.
- Added release verification guidance for local smoke builds versus public notarized builds.
- Expanded unit coverage around launch-at-login, permissions, output formatting, QR fallback, smart actions, and watch mode.

### Verification
- `xcodebuild build-for-testing` succeeds for app, unit tests, and UI tests.
- Repository audit passes via `./scripts/repo_audit.sh`.
- Public distribution still requires notarization with a configured `notarytool` profile when shipping outside local installs.
