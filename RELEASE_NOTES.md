# ScreenTextGrab 1.1.1 Release Notes

## Summary

ScreenTextGrab 1.1.1 is a release-hardening update for the renewed menu bar
app. It keeps the existing feature set intact while tightening the public ZIP,
notarization, update, and CI validation paths.

## Highlights

- Rebuilds the public `ScreenTextGrab.zip` after notarization so the GitHub
  release asset matches the stapled app bundle.
- Publishes `ScreenTextGrab.zip.sha256` alongside the app ZIP.
- Strengthens the built-in updater with GitHub asset digest checks, code
  signature verification, draft/prerelease rejection, and stricter
  newer-version enforcement.
- Stabilizes watch-mode and menu-bar preview UI tests for the LSUIElement app.

## User Impact

- The downloadable release asset and the built-in updater now point at the same
  signed/notarized app package.
- Update failures are safer: mismatched, unsigned, same-version, or corrupted
  downloaded apps are rejected before installation.
- No workflows were removed. Screen capture, clipboard/image/PDF OCR,
  searchable PDF export, snippets, saved regions, table review, and bilingual
  UI behavior remain unchanged.

## Validation Snapshot

- Release version: `1.1.1`
- Public artifact: `ScreenTextGrab.zip`
- Checksum artifact: `ScreenTextGrab.zip.sha256`
- Required release gate: signed build, notarization, stapler validation,
  Gatekeeper validation, unit tests, UI tests, release build, repository audit,
  and the manual smoke matrix.
