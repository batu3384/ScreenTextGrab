# ScreenTextGrab 1.0.1 Release Notes

## Summary

ScreenTextGrab 1.0.1 turns the app from a basic menu bar OCR utility into a broader capture workflow tool for macOS. The release focuses on faster day-to-day use, better installation behavior, clearer permissions, and stronger capture outputs for subtitles, code, tables, and barcodes.

## What's New

### Faster everyday workflow
- Capture from the menu bar or a configurable global shortcut.
- Choose whether the app launches automatically at login.
- Use watch mode to keep monitoring a region and copy updates only when the text changes.

### Better OCR output
- Pick a capture mode for standard text, subtitles, code, or tables.
- Use OCR language preferences with auto-detection support.
- Fall back to QR and barcode detection when text recognition is not the right fit.

### Smarter follow-up actions
- Open captured links directly.
- Start an email or phone action when the result contains contact details.
- Run quick web search, translation, or text-to-speech actions from the latest result.

### Stronger app behavior
- Improved Screen Recording permission handling after first grant.
- Better login-item state reporting and installed-app detection.
- Refined launch behavior for menu bar use versus foreground onboarding.
- Updated icon set and refreshed visual theme.

## User Impact

- Less friction after first-time setup.
- More reliable results on subtitles, code snippets, and tables.
- Better fit for repeated workflows instead of one-off OCR only.
- Cleaner project packaging and release tooling for ongoing maintenance.

## Upgrade Notes

- If you are moving from an older differently signed local build, macOS may require a one-time refresh of Screen Recording permission.
- For public distribution outside direct local installs, complete notarization after running the signed release build.

## Validation Snapshot

- Repository audit passes.
- Build-for-testing succeeds for the app, unit tests, and UI tests.
- Release packaging, signing, and verification scripts are included in `scripts/`.
