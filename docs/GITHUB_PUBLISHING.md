# GitHub Publishing Guide

This file is the public-release handoff for publishing `ScreenTextGrab` as a polished GitHub repository.

## Recommended repository profile

- Repository name: `ScreenTextGrab`
- Visibility: `Public`
- Short description:
  `Local-first macOS menu bar OCR app for screen text, images, PDFs, and reusable capture workflows.`
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
  --description "Local-first macOS menu bar OCR app for screen text, images, PDFs, and reusable capture workflows."
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
./scripts/build_release.sh
```

On a Mac that already has the matching Apple Developer signing identity,
`build_release.sh` auto-detects the team ID. Set `SCREEN_TEXT_GRAB_TEAM_ID`
only when detection fails or you need to override it.

If you are shipping the public `.app`, notarize it before release:

```bash
SCREEN_TEXT_GRAB_NOTARY_PROFILE="your-notary-profile" \
./scripts/notarize_release.sh

APP_PATH=dist/.app-bundles.noindex/ScreenTextGrab.app ./scripts/verify_release.sh
```

Create the GitHub release from terminal:

```bash
gh release create vX.Y.Z \
  dist/ScreenTextGrab.zip \
  dist/ScreenTextGrab.zip.sha256 \
  --title "ScreenTextGrab vX.Y.Z" \
  --notes-file RELEASE_NOTES.md
```

Or use the new wrapper script:

```bash
./scripts/publish_release.sh vX.Y.Z --draft
```

On a properly configured release Mac, the wrapper can also reuse the current
Xcode account session for notarization, so no extra notary environment
variables are required for local publishing.

## Automated GitHub Release workflow

The repository now includes [`.github/workflows/release.yml`](../.github/workflows/release.yml).

- `git push origin vX.Y.Z` will trigger a signed release build on GitHub Actions
- `workflow_dispatch` can publish a release manually without creating the tag first
- if notarization is enabled, the workflow also runs notarization and public verification
- the workflow uploads `dist/ScreenTextGrab.zip` and
  `dist/ScreenTextGrab.zip.sha256` both as artifacts and as GitHub release
  assets

Required GitHub repository secrets:

- `SCREEN_TEXT_GRAB_TEAM_ID`
- `SCREEN_TEXT_GRAB_BUILD_CERTIFICATE_P12_BASE64`
- `SCREEN_TEXT_GRAB_BUILD_CERTIFICATE_PASSWORD`
- `SCREEN_TEXT_GRAB_KEYCHAIN_PASSWORD`

Required for notarization in GitHub Actions:

- `SCREEN_TEXT_GRAB_ASC_KEY_BASE64`
- `SCREEN_TEXT_GRAB_ASC_KEY_ID`
- `SCREEN_TEXT_GRAB_ASC_ISSUER_ID` if your App Store Connect key uses an issuer id

The release workflow intentionally fails when required signing or notarization
secrets are missing. A green Release workflow must mean that the signed ZIP,
checksum, and notarization verification steps actually ran.

Keep the release asset name as `ScreenTextGrab.zip`. The public installer script
[`scripts/install_release.sh`](../scripts/install_release.sh) downloads that
exact asset from the latest GitHub release. Publish a matching
`ScreenTextGrab.zip.sha256` checksum for auditability.

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

`Capture text from screens, images, and PDFs on macOS, then reuse it with snippets, saved regions, and Office-ready output.`

### One paragraph description

`ScreenTextGrab is a local-first macOS menu bar OCR app for turning anything visual into usable text. It supports screen-region capture, clipboard images, local image files, and PDFs with purpose-built modes for standard text, subtitles, code, and tables. Results can be copied as plain text, cleaned text, Markdown, JSON, or Office-ready content for Excel, Numbers, Word, and Pages. The app also includes saved regions, snippets, snippet collections, app profiles, and a built-in table review flow for repeated work.`

## Pre-publish final checklist

- `./scripts/repo_audit.sh`
- unit tests
- UI tests with ad-hoc signing flags
- `./scripts/capture_preview_screenshots.sh` when the UI changed
- `docs/MANUAL_SMOKE_MATRIX.md`
- README screenshots render correctly
- SECURITY and CONTRIBUTING are visible in repo root
- Release scripts are documented
- Public release is notarized before attaching the `.zip`
- `ScreenTextGrab.zip` is rebuilt after notarization and matches
  `ScreenTextGrab.zip.sha256`

## Notes

- GitHub source publishing is ready without notarization.
- End-user downloadable macOS release should be signed and notarized first.
