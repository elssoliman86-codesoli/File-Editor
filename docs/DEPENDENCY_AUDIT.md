# Dependency audit

Versions and repository metadata were checked on **2026-11-20**. No AGPL/GPL engine is used.

| Dependency | Purpose | License / decision |
|---|---|---|
| Flutter 3.50.1 / Dart 3.14.0 | App and test SDK | BSD-style; pinned in CI |
| flutter_quill 11.6.0 + dart_quill_delta | Rich editing / selection / IME | MIT; accepted; tables and advanced embeds are not advertised |
| pdfrx 3.1.0 + PDFium | PDF render, search, selection and page assembly | MIT package; PDFium BSD-style; accepted |
| pdf 3.13.1 / printing 5.15.1 | PDF generation and Android print UI | Apache-2.0; accepted |
| archive 4.7.1 / xml 7.1.0 | OOXML ZIP and XML | BSD/MIT-family; bounded parsing required and tested |
| flutter_riverpod 3.5.0 / go_router 18.1.4 | State and navigation | MIT; accepted |
| sqflite 2.4.6 | Document and reading-position metadata | BSD/MIT-family; no document bodies in DB |
| file_picker 13.4.0 / image_picker 1.2.4 | System pickers | MIT/BSD-family; no broad storage permission |
| share_plus 13.3.1 | Native share sheet | BSD-family; explicit user action only |
| enough_convert 1.7.1 | Legacy text encodings | BSD-family; read-back tested |
| image 4.x (resolved in lockfile) | RGBA to baseline JPEG and image processing | BSD-family; selected instead of the older SDK-incompatible jpeg_encode package |
| Tajawal / Noto Naskh Arabic | UI and document fonts | SIL Open Font License; license files bundled |

PDFBox-Android was evaluated as Apache-2.0 for later native annotation/redaction work, but is not included in this build. MuPDF and iText were excluded because their AGPL/commercial model conflicts with the project constraints. Syncfusion was not used.

The generated `pubspec.lock` must be committed after CI resolves the graph. Transitive licenses require a release-time generated report; the summary above is not a substitute for that report.
