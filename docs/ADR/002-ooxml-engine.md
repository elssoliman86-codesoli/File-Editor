# ADR-002: Custom OOXML package engine

- Status: accepted, Partial support.
- Context: DOCX round-trip and offline operation cannot be delegated to template-only libraries.
- Options: Template package (insufficient), Java POI (heavy/Android incompatibility), custom archive/XML engine.
- Decision: A security-bounded package reader/writer using `archive` and `xml`, with Quill Delta as the editing interchange.
- Reasons: Offline Dart tests, explicit ZIP/XML limits, preservation of unrelated package parts, Arabic paragraph/run properties.
- Trade-offs: The first writer regenerates `word/document.xml`; it does not yet patch each supported paragraph in place. Tables, shapes, headers, fields and advanced objects are not Full editing features. This is disclosed in the UI and feature report.
- Exit plan: Add node identity and XML patching for paragraphs before promoting DOCX support to Full.
- Evidence: `packages/docx_engine/test/docx_engine_test.dart`.
