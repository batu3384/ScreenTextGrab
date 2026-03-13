# Contributing

Thanks for contributing to `ScreenTextGrab`.

## Setup

```bash
xcodegen generate --spec project.yml
```

## Before opening a PR

Run the repository checks:

```bash
./scripts/repo_audit.sh
```

Run unit tests:

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

Run UI tests:

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

## Contribution expectations

- Keep changes scoped and reviewable
- Preserve local-first privacy behavior
- Do not introduce network dependencies for OCR or capture
- Add or update tests when changing capture, permission, clipboard, or UI startup flows
- Avoid adding new entitlements unless they are required and documented

## Areas that deserve extra caution

- Screen Recording permission flow
- Launch-at-login behavior
- Global hotkey registration
- Clipboard output formats
- Table extraction and Office paste behavior

## Pull request guidance

- Explain the user-facing behavior change
- Include test evidence
- Call out permission, signing, or release-script changes clearly
- Add screenshots when UI changes materially affect the user experience
