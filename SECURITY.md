# Security Policy

## Supported Versions

Only the latest commit on the default branch is supported for security fixes.

## Reporting a Vulnerability

Please do not open a public GitHub issue for a security problem.

Send a private report with:

- a short description of the issue
- affected version or commit
- reproduction steps
- impact assessment

If the report includes screenshots or logs, remove personal data first.

## Security Expectations

- No secrets, signing credentials, or personal data should be committed to the repository.
- Public release artifacts must be signed with `Developer ID Application`.
- Public release artifacts must be notarized before distribution.
- Only the Screen Recording permission is expected at runtime.

## Automation Trust Boundaries

- `stg://` / `screentextgrab://` URL schemes are untrusted input. They require Settings → General → URL Automation, or an explicit session/always approval prompt.
- Finder file opens and drag-and-drop imports are treated as user-initiated and do not use the URL-scheme gate.
- The `stg` CLI / launch arguments are treated as user-initiated local commands. PDF export destinations from CLI must stay in the source file's folder; arbitrary destination paths are rejected.
- Clipboard history is stored encrypted at rest (AES-GCM) with a Keychain-backed key.