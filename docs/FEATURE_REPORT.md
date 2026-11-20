# Feature report — 0.1.0 evaluation line

**Status date:** 2026-11-20. `Full` below means implemented at the stated narrow scope, not the entire Master Prompt. Device and external-application verification remains separately recorded in `TEST_REPORT.md`.

| Feature | Priority | Support | Tests | External verification | Notes / limits |
|---|---|---|---|---|---|
| Arabic dark/light UI, RTL and settings | P0 | Partial | Widget test | Device not run | Arabic and English strings; not every accessibility audit complete |
| Import PDF/DOCX/TXT/images | P0 | Partial | Unit format tests | SAF device test pending | 64 MB cap; no legacy binary DOC |
| Recents, favorites, rename, remove working copy | P0 | Partial | Repository design / widget coverage pending | Device not run | Real SQLite records, no fake documents |
| Autosave recovery | P0 | Partial | Engine round-trip tests | Process-death test pending | Payload snapshots, not an operation journal |
| TXT editing | P0 | Full for listed encodings | Codec round-trip tests | Byte/hash check at save | UTF-8/16, Windows-1256/1252, ISO-8859-6; 64 MB, not 100 MB Piece Table |
| TXT search/replace | P0 | Full for plain text | Arabic/regex/whole-word tests | N/A | Case, whole word, Regex captures, Arabic normalization |
| DOCX rich text editing | P0 | Partial | New-file and package round-trip tests | Word/LibreOffice not run | Paragraph/run formatting, headings, lists, links read, embedded images; advanced objects limited |
| DOCX opaque package parts | P0 | Partial | Preservation test | OOXML validator pending | Unrelated parts retained; main document XML is regenerated, so not full opaque paragraph patching |
| PDF viewer | P0 | Partial | Build/API integration | Physical-device rendering pending | PDFium, zoom, thumbnails, outline, password prompt, night filter |
| PDF search/selection/extraction | P0 | Partial | Build/API integration | Arabic extraction pending | Depends on source PDF text layer; scans need OCR (not included) |
| PDF merge/reorder/rotate/duplicate/delete/extract | P0 | Partial | Range unit tests; generated-file count check | qpdf/Acrobat pending | Output is reopened before SAF export; no original-text editing |
| Images to PDF | P1 | Partial | Build/integration pending | Reader validation pending | Baseline JPEG; one image per PDF page |
| PDF export from DOCX/TXT | P0 | Partial | Font asset / generator tests | Arabic copy/paste visual check pending | Layout is text-flow, not Word-identical pagination |
| Share / print | P0/P1 | Partial | Build integration | Device/printer pending | Native share sheet and Printing plugin |
| Templates | P1 | Partial | Widget coverage pending | N/A | Six real Arabic content templates |
| OCR/scanner/annotations/forms/signatures/redaction | P1 | Unsupported | Not run | N/A | No decorative controls; explicitly excluded from this release |
| Global content indexing, tags, trash, versions | P1/P2 | Unsupported | Not run | N/A | Name filtering and favorites only |
| Play production signing | P0 release | Unsupported locally | N/A | N/A | Requires private release keystore; CI APK is debug-signed |
