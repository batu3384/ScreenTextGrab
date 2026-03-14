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
- installs the `stg` terminal command
- cleans stale copies so Spotlight finds the correct app
- launches the app

After installation you can open it from Spotlight with `ScreenTextGrab` or from Terminal with:

```bash
stg open
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
- Supports app-specific capture profiles and optional smart panel sync for frontmost apps
- Lets you save frequently used screen regions and run them again later
- Can OCR a copied screenshot or image directly from the clipboard
- Can OCR a local image file without starting a screen region capture
- Accepts drag-and-drop image and PDF imports directly into the launch panel or menu panel
- Accepts image and PDF files from Finder with `Open With > ScreenTextGrab`
- Exposes a Finder Services action for selected image and PDF files
- Keeps local clipboard history for recent captures, with pinned favorites and quick reuse
- Runs as a focused menu bar utility instead of a large desktop workspace

## How it works

1. Open ScreenTextGrab from the menu bar or global shortcut.
2. Choose the capture mode that matches the content.
3. Select a screen region.
4. Review the result and paste it in the target app.

## Automation

ScreenTextGrab now exposes lightweight automation entry points for shell tools, Apple Shortcuts, and launcher workflows.

### Terminal command

```bash
stg capture --mode table --output office
stg repeat-last --mode code --output markdown
stg saved-region --name "Safari • Tablo"
stg active-snippet
stg snippet --name "Fiyat listesi"
stg snippet-collection --name "Excel Raporlari"
stg clipboard-image --mode standard --output cleaned
stg file-image --path ~/Desktop/table.png --mode table --output office
stg pdf-file --path ~/Desktop/sample.pdf --mode standard --output cleaned
stg pdf-searchable --path ~/Desktop/sample.pdf --destination ~/Desktop/sample-searchable.pdf
stg version
```

### URL scheme

```bash
open 'stg://capture?mode=table&output=office'
open 'stg://repeat-last?mode=code&output=markdown'
open 'stg://saved-region?name=Safari%20%E2%80%A2%20Tablo'
open 'stg://active-snippet'
open 'stg://snippet?name=Fiyat%20listesi'
open 'stg://snippet-collection?name=Excel%20Raporlari'
open 'stg://clipboard-image?mode=standard&output=cleaned'
open 'stg://image-file?path=/absolute/path/to/table.png&mode=table&output=office'
open 'stg://pdf-file?path=/absolute/path/to/sample.pdf&mode=standard&output=cleaned'
open 'stg://searchable-pdf?path=/absolute/path/to/sample.pdf&destination=/absolute/path/to/sample-searchable.pdf'
```

Supported query parameters:

- `name=Saved Region Name`
- `name=Saved Region or Snippet Name`
- `mode=standard|subtitle|code|table`
- `output=smart|plain-text|cleaned|office|markdown|json`
- `languages=tr,en`
- `ocr-auto=true|false`

### Direct app binary

```bash
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --capture --mode table --output office
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --repeat-last --mode code --output markdown
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --saved-region --name "Safari • Tablo"
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --active-snippet
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --snippet --name "Fiyat listesi"
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --snippet-collection --name "Excel Raporlari"
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --clipboard-image --mode standard --output cleaned
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --image-file --path /absolute/path/to/table.png --mode table --output office
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --pdf-file --path /absolute/path/to/sample.pdf --mode standard --output cleaned
/Applications/ScreenTextGrab.app/Contents/MacOS/ScreenTextGrab --pdf-searchable --path /absolute/path/to/sample.pdf --destination /absolute/path/to/sample-searchable.pdf
```

For scripts and launchers, the URL scheme is the recommended stable entry point because it also works while the app is already running.

## Clipboard, image, and PDF OCR

If you already copied a screenshot or image, you can skip region selection entirely:

1. Copy the image to the clipboard.
2. Run `stg clipboard-image` or use the `Panodaki Görseli Oku` button in the menu bar.
3. ScreenTextGrab OCRs the clipboard image with the current mode and output format.

If the image already exists as a file:

1. Run `stg file-image --path /absolute/path/to/image.png`.
2. Or use the `Görsel Dosyası Oku` button in the menu bar.
3. ScreenTextGrab loads the file, runs local OCR, and copies the result with the active mode and output preset.
4. You can also drag the image file directly onto the launch panel or the menu panel.
5. Or choose `Open With > ScreenTextGrab` in Finder.
6. Or use the Finder Services action `ScreenTextGrab ile OCR`.

If the source is a PDF:

1. Run `stg pdf-file --path /absolute/path/to/file.pdf` to copy OCR text from all pages.
2. Or use the `PDF Oku` button in the menu bar.
3. To create an exportable searchable PDF, run `stg pdf-searchable --path /absolute/path/to/file.pdf`.
4. Or use the `Searchable PDF` button in the menu bar and choose where to save the output.
5. You can also drag the PDF file directly onto the launch panel or the menu panel.
6. Or choose `Open With > ScreenTextGrab` in Finder.
7. Or use the Finder Services action `ScreenTextGrab ile OCR`.

## Saved regions

If you repeatedly OCR the same part of the screen:

1. Capture it once.
2. Open `Ayarlar > Geçmiş`.
3. Use `Son Alanı Kaydet`.
4. Run it later from the saved regions list, the `stg saved-region` command, or the URL scheme.
5. When the related app becomes active again, ScreenTextGrab surfaces the newest matching saved region directly in the menu panel.
6. If accessibility access is already enabled, the suggestion becomes smarter and prefers regions that match the current window title.
7. If `Akıllı Başlangıç` is enabled, the main capture button automatically runs the best matching saved region instead of asking you to select an area again.

## App profiles

If different apps need different OCR defaults:

1. Open `Ayarlar > Sistem`.
2. Save a profile from `Çalışan Uygulamadan Profil Oluştur`.
3. ScreenTextGrab will automatically use that profile during capture whenever the app becomes active.
4. If you also enable `Akıllı Panel Senkronu`, the menu panel updates its visible mode, output preset, and OCR languages to match the same app profile.

## Saved snippets

If you want to keep reusable OCR results without searching through the full history:

1. Open `Ayarlar > Geçmiş`.
2. Save the latest result with `Son Sonucu Kaydet` or use `Snippet Yap` on any history row.
3. Re-copy the saved snippet later from the snippet list, the `stg snippet` command, or the URL scheme.
4. Snippets preserve the original capture mode and output preset, so table, code, and Office formatting stay intact.
5. Snippets are automatically tagged from the source app, capture mode, and output style so you can filter them like lightweight collections.
6. You can add your own tags and search by name, text, app, or tag from the same settings panel.
7. You can save the current snippet filter as a named collection and reopen the same view later with one click.
8. Saved collections can also be opened from `stg snippet-collection`, the URL scheme, or Shortcuts.
9. When the related app becomes active again, ScreenTextGrab can surface the best matching snippet collection directly in the menu panel.
10. If exactly one snippet is the clear match for the active app or window, ScreenTextGrab offers it directly from the menu so you can copy it in one click.
11. If multiple snippets are still relevant, the menu panel shows the top matching snippet actions so you can copy one without opening History first.
12. When you keep reusing the same snippet for an app or window, ScreenTextGrab learns that preference and promotes it as the primary action next time.
13. The same active app suggestion can also be triggered from automation with `stg active-snippet`, the `stg://active-snippet` URL, or Shortcuts.
14. If `Akıllı Koleksiyon Senkronu` is enabled, the `Geçmiş` tab automatically applies the best matching collection for the active app.
15. When the active app has a saved profile, copying a saved snippet automatically adapts the output preset and clipboard payload for that target app without losing the snippet's original source metadata.
16. The same target-app adaptation also applies when you re-copy a history item, use `copy as...` actions, or copy a reviewed table from the table editor.

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

## History and favorites

ScreenTextGrab keeps recent capture results locally inside the app.

- Pin important items so they stay at the top of the history list
- Save reusable entries as named snippets for one-click copy later
- Filter the history view to pinned entries only
- Re-copy previous results without repeating OCR
- Keep table, code, subtitle, and file-based OCR results in one place

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
