# Test report

## Environment

The local Termux device cannot run Flutter or the official x86_64 Dart binary (`Exec format error` on ARM64). The actual CI environment and commands are defined in `.github/workflows/android.yml`. Results must be appended from the GitHub run; absence of a result is not a pass.

## Matrix

| Test | Status | Evidence / limitation |
|---|---|---|
| T01 PDF normal/Arabic/large/encrypted/corrupt | Not run on device | PDFium integration compiled by CI only; physical corpus pending |
| T02 DOCX different producers | Partial unit coverage | New OOXML and preserved package tested; Word/LibreOffice/Google Docs corpus pending |
| T03 TXT encodings | Automated package tests | UTF-8/16 and Windows-1256 round trips in `packages/txt_engine/test` |
| T04 Edit/save TXT/DOCX/PDF | Partial | Read-back and generated-file checks in code; end-to-end device test pending |
| T05 New document/templates | Widget/integration pending | Six templates implemented; no fake content |
| T06 Images | Build/integration pending | Image picker and base64 DOCX embed; JPEG PDF conversion implemented |
| T07 Links | Partial unit/read support | Link launching not advertised |
| T08 Tables | Unsupported for full editing | Preservation warning only |
| T09 PDF export/Arabic | Build pending | Visual/copy check in Acrobat required |
| T10 DOCX export | Package unit tests | External Word/LibreOffice validation pending |
| T11 Arabic Bidi corpus | Normalization tests only | 30 mixed cases; this does not prove pixel-perfect Bidi layout |
| T12 Large documents | Not run | 64 MB cap; no 100 MB claim |
| T13 Crash recovery | Not run on device | Recovery payload implementation only |
| T14 Android versions/SAF | Not run | Needs device matrix |
| T15 Search/replace | Automated package tests | Arabic, case, whole-word and Regex captures |
| T16 PDF pages | Range tests + runtime count check | qpdf and external readers pending |
| T17 Annotations/signature | Unsupported | Not advertised |
| T18 Redaction | Unsupported | Not advertised |
| T19 PDF protection | View password prompt only | Protection writing not advertised |
| T20 Forms | Unsupported | Not advertised |
| T21 OCR | Unsupported | Not advertised |
| T22 Printing | Build integration only | Physical printer/save-as-PDF pending |
| T23 External intents | Kotlin implementation | Instrumented device test pending |
| T24 External modification conflict | Unsupported | Not advertised |
| T25 Malformed ZIP/XML | Unit security tests | DTD and Zip Slip cases; broader fuzzing pending |
| T26 Performance budgets | Not run | No invented FPS/startup numbers |
| T27 Accessibility | Partial semantics/theme work | TalkBack and 200% scale audit pending |
| T28 RTL/localization | Widget smoke test | Visual Golden audit pending |
| T29 Rotation/process death | Not run | Device integration pending |
| T30 DB migration | Schema v1 only | Future migration tests required |

## Build evidence

The workflow records analyze/test/build exit codes, APK signature verification, file sizes and SHA-256 checksums. See the linked GitHub Actions run and artifacts for actual results.
