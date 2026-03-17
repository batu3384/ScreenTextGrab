# Changelog

All notable released changes to ScreenTextGrab are documented here.

## Unreleased

- No unreleased changes are recorded yet.

## 1.1.0 - 2026-03-18

### Added
- English and Turkish interface selection inside the app.
- Menu bar update flow with check, download progress, and restart-to-update states.
- Finder Services localization resources for English and Turkish builds.

### Improved
- Refreshed the menu bar interface, settings surfaces, and product screenshots.
- Updated the README and release docs to match the current import, localization,
  and product-tour flows.
- Multi-file image and PDF imports now queue and run one by one instead of
  silently dropping later files.

### Fixed
- Import routing now recognizes supported image and PDF files even when they
  arrive without a filename extension.
- Update button accessibility labels now match the visible update state.
- Saved-region Smart Start messaging no longer duplicates the same suggestion
  in multiple places inside the menu panel.

## 1.0.3 - 2026-03-15

### Fixed
- Corrected the GitHub release workflow paths used for release verification.
- Synced the shipped app version and build number with the public release.

## 1.0.2 - 2026-03-15

### Added
- User-configurable global hotkey with persistence and reset to default.
- Launch-at-login support backed by `SMAppService`.
- OCR language preferences with automatic language detection support.
- Multiple capture modes: `Standard`, `Subtitle`, `Code`, and `Table`.
- QR and barcode fallback when OCR is weak or empty.
- Watch mode for repeated OCR on a selected region.
- Smart actions for links, email addresses, phone numbers, search, translation,
  and text-to-speech.
- Searchable persisted capture history with export support.
- CI, repository audit, release build, notarization, verification, and cleanup
  scripts.

### Improved
- Menu bar interface was compacted and reworked for clearer controls and
  smaller-screen behavior.
- Screen Recording permission checks now use passive verification before
  prompting the user.
- Capture behavior is mode-aware, including subtitle-focused OCR and
  code/table-specific formatting.
- Installed-app detection handles both `/Applications` and `~/Applications`.

### Fixed
- Repeated Screen Recording permission prompts after access had already been
  granted.
- Launch-at-login state mismatches and stale registration edge cases.
- Global hotkey registration failures with weak user feedback.
- Menu panel overflow and unreadable capture-mode controls.
- Release builds incorrectly carrying development entitlements.
