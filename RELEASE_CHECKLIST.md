# ScreenTextGrab Release Checklist

## Packaging
- Generate the Xcode project before release builds:

```bash
xcodegen generate --spec project.yml
```

- Build the release archive and export a `Developer ID Application` package:

```bash
./scripts/build_release.sh
```

  If the release Mac already has a matching Apple Developer signing identity,
  the script auto-detects the team ID. `SCREEN_TEXT_GRAB_TEAM_ID` is only
  needed when auto-detection is not possible.

- To build, notarize, verify, and publish the GitHub release in one local command:

```bash
./scripts/publish_release.sh v1.0.1 --draft
```

- The script uses Xcode's `developer-id` export flow. Make sure the selected Apple Developer team in Xcode has access to create or use Developer ID signing assets.

- Submit the signed app for notarization and staple the ticket:

```bash
SCREEN_TEXT_GRAB_NOTARY_PROFILE="<keychain-profile>" \
./scripts/notarize_release.sh
```

- If you do not want to pre-create a keychain profile, the notarization script also accepts direct credentials:

```bash
SCREEN_TEXT_GRAB_APPLE_ID="<apple-id>" \
SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD="<app-specific-password>" \
SCREEN_TEXT_GRAB_NOTARY_TEAM_ID="<YOUR_TEAM_ID>" \
./scripts/notarize_release.sh
```

- To store those credentials once in the keychain for repeatable releases:

```bash
SCREEN_TEXT_GRAB_NOTARY_PROFILE="ScreenTextGrab-Notary" \
SCREEN_TEXT_GRAB_APPLE_ID="<apple-id>" \
SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD="<app-specific-password>" \
./scripts/setup_notary_profile.sh
```

- If the same Apple Developer account is already signed into Xcode on the release Mac, you can let Xcode handle the notary upload session directly:

```bash
./scripts/notarize_release.sh
```

- GitHub Actions can run the same public release flow from [`.github/workflows/release.yml`](.github/workflows/release.yml).
  Required secrets:
  - `SCREEN_TEXT_GRAB_TEAM_ID`
  - `SCREEN_TEXT_GRAB_BUILD_CERTIFICATE_P12_BASE64`
  - `SCREEN_TEXT_GRAB_BUILD_CERTIFICATE_PASSWORD`
  - `SCREEN_TEXT_GRAB_KEYCHAIN_PASSWORD`
  - for notarization: `SCREEN_TEXT_GRAB_ASC_KEY_BASE64`, `SCREEN_TEXT_GRAB_ASC_KEY_ID`, and `SCREEN_TEXT_GRAB_ASC_ISSUER_ID` when your App Store Connect key uses an issuer id

- If Apple processing is slow, increase the Xcode polling timeout:

```bash
SCREEN_TEXT_GRAB_XCODE_NOTARY_TIMEOUT_SECONDS=3600 \
./scripts/notarize_release.sh
```

- Verify the notarized release package:

```bash
./scripts/verify_release.sh
```

- For a local signed smoke build that is not Developer ID / notarized, run:

```bash
VERIFY_MODE=local ./scripts/verify_release.sh
```

- To rerun the launch-panel UI automation locally, use the same ad-hoc signing flags as CI:

```bash
xcodebuild test \
  -project ScreenTextGrab.xcodeproj \
  -scheme ScreenTextGrab \
  -only-testing:ScreenTextGrabUITests \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='-' \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM=''
```

- Install the final signed app to `/Applications/ScreenTextGrab.app`.
- Launch from `/Applications` (do not run from temporary build paths).
- Before smoke test, remove old copies:

```bash
./scripts/cleanup_app_copies.sh
```

## Signing Verification
Run:

```bash
codesign -dv --verbose=4 /Applications/ScreenTextGrab.app
spctl -a -vv /Applications/ScreenTextGrab.app
xcrun stapler validate /Applications/ScreenTextGrab.app
```

Expected:
- `Authority` contains **Developer ID Application**
- `TeamIdentifier` is set
- `Identifier` is `dev.screentextgrab.app`
- no `com.apple.security.get-task-allow` entitlement
- Gatekeeper result is `accepted`
- Stapler validation succeeds
- no `NSAppleEventsUsageDescription` in the release bundle

## Permission Smoke Test
- Remove previous Screen Recording permission for the app from System Settings.
- Optional hard reset:

```bash
./scripts/cleanup_app_copies.sh --reset-tcc
```
- Launch app and request permission from app UI.
- Grant permission.
- Quit and relaunch app.
- Verify first capture after relaunch works without repeated permission loop.

## Capture + Clipboard Smoke Test
- Trigger capture via menu button and via `⌥S`.
- Select text area on primary display and a secondary display.
- Confirm OCR text appears in menu panel.
- Confirm clipboard content exactly matches copied text.
- Confirm clipboard failure (if forced) does not show success message.
