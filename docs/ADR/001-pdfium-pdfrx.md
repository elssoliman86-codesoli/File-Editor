# ADR-001: PDFium via pdfrx

- Status: accepted for the 0.1.x evaluation line.
- Context: The app needs real rendering, text selection, search and page manipulation without AGPL dependencies.
- Options: Android PdfRenderer (view only), PDFBox-Android (editing but needs a separate renderer), pdfrx/PDFium, MuPDF (rejected: AGPL).
- Decision: pdfrx 3.1.0, isolated behind feature controllers.
- Reasons: Android support, PDFium text/geometry APIs, page combination/rotation, MIT package license, maintained current release.
- Trade-offs: Native binary size and PDFium behavior differences. Original PDF content editing and redaction are not inferred from viewer capability.
- Exit plan: The organizer accepts document/page abstractions and can be moved to a native PDFBox bridge if a required security or annotation feature is unavailable.
- Evidence: Upstream `doc/PDF-Page-Manipulation.md`, `Text-Search.md`, package release queried 2026-11-20.
