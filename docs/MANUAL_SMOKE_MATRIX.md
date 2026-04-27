# Manual Smoke Matrix

Run this matrix after UI-affecting changes, release candidates, or screenshot refreshes.

## Main Panel

1. Open the menu bar panel in English and Turkish.
2. Verify the panel fits without clipped text on the default menu panel width.
3. Confirm the following sections remain visible and ordered:
   - status
   - capture action
   - mode selection
   - output selection
   - contextual workflow actions
   - import/settings access
4. Confirm low-frequency settings do not appear in the main panel:
   - interface language
   - launch at login
   - hotkey reset
5. Confirm Smart Start does not duplicate the same saved-region notice below the primary CTA.

## Capture and Import

1. Start a standard region capture.
2. Start a table capture and verify Office output still pastes correctly.
3. Import a clipboard image from the Import menu.
4. Import an image file from the Import menu.
5. Import a PDF and confirm text extraction succeeds.
6. Export a searchable PDF and confirm the generated file is searchable.
7. Drop multiple supported files and verify they queue instead of silently skipping later files.

## Saved Workflows

1. Save a region and rerun it.
2. Enable Smart Start and confirm the correct saved region becomes the main CTA when applicable.
3. Save a snippet from history and copy it back out.
4. Save a snippet collection and verify auto-sync against the active app still works.
5. Confirm active snippet quick picks appear only when they add value.

## Update Flow

1. Verify the header update button is visible and readable in idle state.
2. Verify the button text, icon, and accessibility label stay aligned for:
   - idle
   - checking
   - downloading
   - ready to restart
   - failure
3. Install the latest public release, then update to the candidate release and confirm:
   - the newer version is detected
   - the download reaches 100%
   - `Restart & Update` relaunches the new app
   - the app does not downgrade or reinstall the same version

## Settings

1. Review all four tabs:
   - General
   - OCR
   - History
   - Diagnostics
2. Confirm long localized text does not clip inside settings cards.
3. Confirm action rows use compact, consistent button sizing.
4. Confirm all toggles and detail copy still reflect actual product behavior.

## Accessibility and Localization

1. Verify English and Turkish copy tone matches across the menu, settings, and diagnostics.
2. Check VoiceOver labels for:
   - update button
   - capture mode controls
   - OCR language controls
   - launch at login toggle
3. Verify Finder import and services labels match the system language.

## Release Readiness

1. Re-run:
   - repo audit
   - unit tests
   - UI tests
   - release build
2. Verify the signed/notarized public artifact:
   - `codesign --verify --deep --strict`
   - `spctl -a -vv`
   - `xcrun stapler validate`
   - `shasum -a 256 -c dist/ScreenTextGrab.zip.sha256`
3. Smoke fresh install from `dist/ScreenTextGrab.zip` on a clean macOS user account.
4. Refresh README screenshots with `scripts/capture_preview_screenshots.sh` after any material UI change.
