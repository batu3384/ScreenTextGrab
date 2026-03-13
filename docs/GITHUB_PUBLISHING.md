# GitHub Publishing Guide

This file is the public-release handoff for publishing `ScreenTextGrab` as a polished GitHub repository.

## Recommended repository profile

- Repository name: `ScreenTextGrab`
- Visibility: `Public`
- Short description:
  `macOS menu bar OCR app for capturing on-screen text, code, subtitles, and tables with Office-compatible paste output.`
- Suggested topics:
  `macos`, `swift`, `swiftui`, `ocr`, `vision`, `menubar`, `clipboard`, `screen-capture`, `productivity`, `office`

## Recommended GitHub surface

- Enable Issues
- Enable Discussions only if you want community feature requests
- Disable Wiki unless you plan to maintain separate long-form docs there
- Keep `main` as the default branch
- Protect `main` after first push if you plan to accept pull requests

## Repo assets already prepared

- README with screenshots and feature overview
- SECURITY policy
- CONTRIBUTING guide
- CI workflow
- CHANGELOG and release notes
- Release helper scripts under `scripts/`
- Product screenshots under `docs/screenshots/`

## First publish from terminal

If the local repo is not pushed yet:

```bash
cd ScreenTextGrab

git branch -M main
git add .
git commit -m "Prepare public GitHub release"
```

Create the GitHub repo and push with GitHub CLI:

```bash
gh repo create ScreenTextGrab \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "macOS menu bar OCR app for capturing on-screen text, code, subtitles, and tables with Office-compatible paste output."
```

If the GitHub repo already exists, just connect and push:

```bash
git remote add origin git@github.com:<YOUR_ACCOUNT>/ScreenTextGrab.git
git push -u origin main
```

## Optional repository tuning with GitHub CLI

```bash
gh repo edit \
  --enable-issues \
  --enable-projects=false \
  --enable-wiki=false \
  --delete-branch-on-merge
```

## Create the first GitHub release

Build the distributable artifacts first:

```bash
SCREEN_TEXT_GRAB_TEAM_ID="<YOUR_TEAM_ID>" \
./scripts/build_release.sh
```

If you are shipping the public `.app`, notarize it before release:

```bash
SCREEN_TEXT_GRAB_NOTARY_PROFILE="your-notary-profile" \
./scripts/notarize_release.sh

./scripts/verify_release.sh
```

Create the GitHub release from terminal:

```bash
gh release create v1.0.1 \
  dist/ScreenTextGrab.zip \
  --title "ScreenTextGrab v1.0.1" \
  --notes-file RELEASE_NOTES.md
```

Or use the new wrapper script:

```bash
./scripts/publish_release.sh v1.0.1 --draft
```

## Automated GitHub Release workflow

The repository now includes [`.github/workflows/release.yml`](../.github/workflows/release.yml).

- `git push origin v1.0.1` will trigger a signed release build on GitHub Actions
- `workflow_dispatch` can publish a release manually without creating the tag first
- if notarization is enabled, the workflow also runs notarization and public verification
- the workflow uploads `dist/ScreenTextGrab.zip` both as an artifact and as the GitHub release asset

Required GitHub repository secrets:

- `SCREEN_TEXT_GRAB_TEAM_ID`
- `SCREEN_TEXT_GRAB_BUILD_CERTIFICATE_P12_BASE64`
- `SCREEN_TEXT_GRAB_BUILD_CERTIFICATE_PASSWORD`
- `SCREEN_TEXT_GRAB_KEYCHAIN_PASSWORD`

Required for notarization in GitHub Actions:

- `SCREEN_TEXT_GRAB_ASC_KEY_BASE64`
- `SCREEN_TEXT_GRAB_ASC_KEY_ID`
- `SCREEN_TEXT_GRAB_ASC_ISSUER_ID` if your App Store Connect key uses an issuer id

Keep the release asset name as `ScreenTextGrab.zip`. The public installer script
[`scripts/install_release.sh`](../scripts/install_release.sh) downloads that
exact asset from the latest GitHub release.

The one-line public bootstrap installer
[`scripts/bootstrap_install.sh`](../scripts/bootstrap_install.sh) prefers that
release asset when it exists, then falls back to a source install.

## Suggested release body structure

- What the app does in one sentence
- Highlights for this version
- Installation note for macOS users
- Permission note: first launch requires Screen Recording access
- Known limitation note only if there is a real unresolved issue

## Recommended store text

### Short pitch

`Capture text from anywhere on macOS and paste it back as plain text, Markdown, JSON, or Office-ready content.`

### One paragraph description

`ScreenTextGrab is a local-first macOS menu bar OCR tool for grabbing text from any on-screen region. It supports standard text capture, subtitle-focused OCR, code-friendly output, and table extraction with Office-compatible clipboard formats. The app also includes capture history, launch-at-login support, a global shortcut, and a table review window for fixing OCR output before copying again.`

## Pre-publish final checklist

- `./scripts/repo_audit.sh`
- unit tests
- UI tests with ad-hoc signing flags
- README screenshots render correctly
- SECURITY and CONTRIBUTING are visible in repo root
- Release scripts are documented
- Public release is notarized before attaching the `.zip`

## Notes

- GitHub source publishing is ready without notarization.
- End-user downloadable macOS release should be signed and notarized first.
