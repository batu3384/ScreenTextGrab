# ScreenTextGrab

ScreenTextGrab is a macOS menu bar OCR app for grabbing text from any on-screen region, then pasting it back in the format that fits the job.

It is built for fast daily capture, code snippets, subtitles, and spreadsheet-like tables. OCR runs locally with Apple's Vision framework and keeps screenshots and recognized text on the device.

![Launch panel](docs/screenshots/launch-panel.png)

## Why it exists

- Capture text from anywhere on screen without switching apps
- Use a global shortcut for fast region selection
- Switch between `Standard`, `Subtitle`, `Code`, and `Table` capture modes
- Paste results as plain text, cleaned text, Markdown, JSON, or `Office`-compatible rich content
- Repair OCR-extracted tables in a dedicated table editor before copying again
- Keep a local searchable history of captured text

## Screenshots

| Launch Panel | Settings | Table Review |
| --- | --- | --- |
| ![Launch panel](docs/screenshots/launch-panel.png) | ![Settings](docs/screenshots/settings-general.png) | ![Table review](docs/screenshots/table-review.png) |

## Core workflows

### Capture modes

- `Standard`: balanced OCR for documents, UI text, dashboards, and general app content
- `Subtitle`: tuned for lower-third text and repeated subtitle sampling
- `Code`: preserves line structure and whitespace more carefully
- `Table`: extracts row and column structure for Excel, Numbers, and Word workflows

### Output presets

- `Smart`: best default output for the active capture mode
- `Plain Text`: direct unformatted text
- `Cleaned`: OCR cleanup for noisy captures
- `Office`: rich clipboard output for Word and Excel
- `Markdown`: good for code blocks and structured notes
- `JSON`: structured output for automation or post-processing

## Privacy

ScreenTextGrab does not upload screenshots or OCR results to a remote service. OCR runs locally with Apple's Vision framework. The app asks only for Screen Recording permission because that is required to capture the selected area.

## Requirements

- macOS 14 or newer
- Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Local development

Generate the project:

```bash
xcodegen generate --spec project.yml
```

Run the unit tests:

```bash
xcodebuild test \
  -project ScreenTextGrab.xcodeproj \
  -scheme ScreenTextGrab \
  -only-testing:ScreenTextGrabTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=''
```

Run the UI tests with ad-hoc signing for the runner:

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

Build a local release candidate without signing:

```bash
xcodebuild build \
  -project ScreenTextGrab.xcodeproj \
  -scheme ScreenTextGrab \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=''
```

Run the repository audit:

```bash
./scripts/repo_audit.sh
```

## Public release

For a public macOS release you still need:

1. Your own Apple Developer team in Xcode with `Developer ID Application`
2. Notarization credentials through one of these paths:
   - `xcrun notarytool store-credentials`
   - `SCREEN_TEXT_GRAB_APPLE_ID` + `SCREEN_TEXT_GRAB_APP_SPECIFIC_PASSWORD`
   - App Store Connect API key environment variables

Build, notarize, and verify:

```bash
SCREEN_TEXT_GRAB_TEAM_ID="<YOUR_TEAM_ID>" \
./scripts/build_release.sh

SCREEN_TEXT_GRAB_NOTARY_PROFILE="your-notary-profile" \
./scripts/notarize_release.sh

./scripts/verify_release.sh
```

More detail:

- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
- [RELEASE_NOTES.md](RELEASE_NOTES.md)
- [CHANGELOG.md](CHANGELOG.md)

## GitHub publishing

Repository publishing, release commands, suggested repository description, and terminal workflow are documented here:

- [docs/GITHUB_PUBLISHING.md](docs/GITHUB_PUBLISHING.md)

## Open source hygiene

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [LICENSE](LICENSE)
