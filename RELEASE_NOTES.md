# ScreenTextGrab 1.1.0 Release Notes

## Summary

ScreenTextGrab 1.1.0 turns the post-release polish work into a full product
update: the app interface is now bilingual, the menu bar panel is cleaner, the
release surface is better aligned with the shipped behavior, and local image/PDF
imports behave more reliably.

## Highlights

- Added in-app interface language switching for English and Turkish.
- Added a menu bar updater flow with check, download progress, and
  `Restart & Update`.
- Improved menu panel density, wording, and screenshot/documentation accuracy.
- Queued multi-file Finder and import automation requests instead of handling
  only the first supported file.
- Localized Finder Services resources for both shipped interface languages.

## User Impact

- The app feels more productized on first launch and inside the menu bar.
- Users can keep the UI in English or Turkish without changing the system
  language.
- Imported images and PDFs behave more predictably when multiple files are sent
  to the app at once.
- The local release ZIP stays compatible with the one-command installer and the
  built-in update mechanism.

## Validation Snapshot

- Release ships as tag `v1.1.0`.
- Public artifact remains `ScreenTextGrab.zip`.
- Signed build, notarization, stapler validation, Gatekeeper validation, unit
  tests, UI tests, and repository audit all passed for this release.
