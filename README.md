# ScreenTextGrab

[![CI](https://github.com/batu3384/ScreenTextGrab/actions/workflows/ci.yml/badge.svg)](https://github.com/batu3384/ScreenTextGrab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/batu3384/ScreenTextGrab)](https://github.com/batu3384/ScreenTextGrab/releases/latest)

ScreenTextGrab is a local-first macOS menu bar OCR app for capturing text from any on-screen region and pasting it back in the format that fits the job.

It is built for everyday text capture, subtitles, code snippets, and spreadsheet-like tables. OCR runs locally with Apple's Vision framework, so screenshots and recognized text stay on the device.

Latest notarized release: [GitHub Releases](https://github.com/batu3384/ScreenTextGrab/releases/latest)

## Install

### One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/batu3384/ScreenTextGrab/main/scripts/bootstrap_install.sh | bash
```

This command:

- downloads the latest release when available
- installs `ScreenTextGrab.app` into `/Applications`
- cleans stale copies so Spotlight finds the correct app
- launches the app

After installation you can open it from Spotlight with `ScreenTextGrab` or from Terminal with:

```bash
open -a ScreenTextGrab
```

On first launch, macOS asks for Screen Recording permission once. After you allow it, reopen the app and continue normally.

### Install from a local clone

```bash
./scripts/install.sh
```

## Why it is useful

- Captures text from any screen region without switching apps
- Supports `Standard`, `Subtitle`, `Code`, and `Table` OCR modes
- Copies results as `Plain Text`, `Cleaned`, `Markdown`, `JSON`, or rich `Office` output
- Preserves row and column structure for Excel, Numbers, Word, and Pages workflows
- Includes a table review editor for fixing OCR-extracted tables before pasting again
- Keeps local clipboard history for recent captures
- Runs as a focused menu bar utility instead of a large desktop workspace

## How it works

1. Open ScreenTextGrab from the menu bar or global shortcut.
2. Choose the capture mode that matches the content.
3. Select a screen region.
4. Review the result and paste it in the target app.

## Capture modes

| Mode | Best for |
| --- | --- |
| `Standard` | documents, UI text, dashboards, general interface copy |
| `Subtitle` | video subtitles, overlays, repeated lower-third text |
| `Code` | code blocks, logs, terminals, developer tools |
| `Table` | spreadsheets, price lists, multi-column layouts |

## Output formats

| Output | Use case |
| --- | --- |
| `Smart` | best default output for the selected mode |
| `Plain Text` | raw text paste |
| `Cleaned` | cleaned OCR output from noisy captures |
| `Office` | rich paste for Excel, Numbers, Word, and Pages |
| `Markdown` | notes, docs, code blocks |
| `JSON` | automation and structured post-processing |

## Office-ready tables

For the best spreadsheet workflow:

1. Choose `Table` mode.
2. Choose `Office` output.
3. Capture the table.
4. Adjust rows or columns in the built-in table review window if needed.
5. Paste into Excel, Numbers, Word, or Pages.

## Screenshots

| Menu Panel | Launch Panel |
| --- | --- |
| ![Menu panel](docs/screenshots/menu-panel.png) | ![Launch panel](docs/screenshots/launch-panel.png) |

| Settings | Table Review |
| --- | --- |
| ![Settings](docs/screenshots/settings-general.png) | ![Table review](docs/screenshots/table-review.png) |

## Privacy

ScreenTextGrab does not upload screenshots or OCR results to a remote service. OCR runs locally with Apple's Vision framework. The app requests Screen Recording permission because macOS requires it for region capture.

## Requirements

- macOS 14 or newer
- Xcode 15 or newer only if you are building from source

## Project docs

- [Release downloads](https://github.com/batu3384/ScreenTextGrab/releases/latest)
- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Release checklist](RELEASE_CHECKLIST.md)
- [GitHub publishing guide](docs/GITHUB_PUBLISHING.md)
- [License](LICENSE)
