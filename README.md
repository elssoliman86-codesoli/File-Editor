# مِداد — Midad

Offline-first Arabic document workspace for Android, built with Flutter. The project implements a functional, installable **0.1.0 evaluation release**, with explicit support levels rather than claims of complete Microsoft Word or Adobe Acrobat compatibility.

## What works in this release

- Arabic/English RTL-aware interface with dark, light and AMOLED themes.
- Real local recents, favorites, rename, templates and recovery copies.
- TXT editing, search/replace, Arabic normalization, Regex, UTF-8/UTF-16, Windows-1256/1252 and ISO-8859-6.
- Partial DOCX rich-text editing: paragraphs, headings, basic character formatting, lists and embedded images. OOXML packages are genuinely generated and reopened.
- PDFium viewer with text selection/search, outline, thumbnails, zoom, night filter and password prompt.
- PDF merge, reorder, rotate, duplicate, delete and page extraction through PDFium.
- Images-to-PDF, Arabic PDF generation from text, native sharing and printing.
- SAF export with streamed SHA-256 read-back verification; no broad storage permission.

Read [the feature report](docs/FEATURE_REPORT.md) and [known limitations](docs/KNOWN_LIMITATIONS.md) before using the output for critical documents. Always review exported DOCX files in the application you intend to use.

## APK

GitHub Actions builds universal and per-ABI debug-signed evaluation APKs after formatting, static analysis and tests. They are downloadable from the workflow artifacts and the repository's evaluation release. They are **not production-signed Play Store builds**.

## Build

See [docs/BUILD.md](docs/BUILD.md). The SDK is pinned to Flutter 3.50.1 / Dart 3.14.0 and Android API 36, minSdk 24.

## Architecture

- `lib/`: Flutter presentation, platform bridge, local repositories and use-case services.
- `packages/document_core`: format-independent contracts.
- `packages/arabic_text`: normalization, offset-preserving search and numerals.
- `packages/txt_engine`: encodings, EOL handling and statistics.
- `packages/docx_engine`: security-bounded OOXML reader/writer and range utilities.
- `android/`: Kotlin SAF, incoming intents, FileProvider and secure-window bridge.
- `docs/ADR`: engine and storage decisions with exit plans.

## Privacy

No account, analytics, tracking or document upload. Processing and recovery storage are local. The main Android manifest does not request INTERNET, camera, microphone or broad storage permissions. Debug/profile builds retain Flutter's development-only INTERNET permission.

## License and third-party components

Project source is provided under the MIT License in `LICENSE`. Font licenses are bundled under `assets/fonts/`. See `THIRD_PARTY_LICENSES.md` and `docs/DEPENDENCY_AUDIT.md`.
