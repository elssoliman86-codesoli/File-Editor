# Known limitations

1. This is a functional **0.1.0 evaluation build**, not the complete nine-phase Master Prompt or a Word/Acrobat replacement.
2. DOCX editing is partial. `word/document.xml` is regenerated for supported paragraphs; unsupported main-document content may change despite unrelated package parts being preserved. Tables, floating objects, fields, comments, Track Changes, footnotes, SmartArt, OMML, headers/footers and exact Word pagination need review or are not editable.
3. PDF features are viewing/search/selection and page assembly. Original content-stream editing, annotations, form filling, signatures, redaction, encryption and compression are not advertised.
4. OCR, camera scanning, Arabic spellchecking and PDF-to-DOCX conversion are not implemented.
5. Import is capped at 64 MB. A Rope/Piece Table, memory-mapped large files and 1000-page performance budgets have not been validated.
6. Physical-device checks are required for IME variants, SAF cloud providers, print services, process death, RTL visuals and Android 7–16 compatibility.
7. Microsoft Word, Google Docs, LibreOffice, Acrobat, qpdf and veraPDF checks must not be marked passed without their actual logs.
8. APKs produced by the default CI workflow are debug-signed evaluation artifacts. AAB and production signing require an owner-provided private key and a release decision.
9. The application has no production network feature. Debug/profile manifests include Flutter's development INTERNET permission; the main manifest does not request it.
10. Recovery stores snapshots, not a complete operation-level WAL/version history.
11. `packages/arabic_text` and `packages/document_core` have no tests yet; CI reports a warning for each instead of failing. Only `docx_engine` (4 tests), `txt_engine` (10) and the app (1 smoke test) are covered.
12. The app module still applies the Kotlin Gradle Plugin. Flutter 3.50 prints a warning that this will fail in a future release; migrating to AGP built-in Kotlin means dropping `org.jetbrains.kotlin.android` and `android.builtInKotlin=false`, and needs its own verification.
13. With file_picker 13 the picker returns a private cache copy. Only a `content://` URI is recorded as a document's source, so a picked file is not written back to its original location.
