# Threat model

## Assets

User documents, private working copies, signatures (future), source URI grants, search metadata and temporary exports.

## Attack surfaces and controls

- Malicious ZIP/DOCX: 64 MB input cap, entry count and expanded-size caps, path normalization, symlink rejection, checksum verification.
- Malicious XML: DTD/entity declaration rejection and nesting-depth checks before parsing. No external entities are intentionally resolved.
- Malicious PDF: PDFium runs as the parser; JavaScript and attachments are never launched by Midad. Original text editing/redaction is not claimed.
- Image decompression bombs: imports are capped at 64 MB and conversion targets 2000 px width. Pixel limits still need device stress testing.
- Unsafe external links: this version does not auto-open arbitrary document links.
- Data loss: original imports are read-only inputs; edits go to separate recovery files; export is a user-selected new document followed by streamed SHA-256 read-back.
- Other apps: workspace and SQLite live in app-private directories. FileProvider is non-exported and grants are initiated only by explicit sharing.
- Backup leakage: Android backup is disabled in the manifest.

## Residual risks

PDF parsing bugs are native upstream risks. Large DOCX/PDF memory behavior needs physical-device tests. SAF providers differ in sync support; the Kotlin write path flushes and syncs when available, then verifies bytes. Root-compromised devices are outside the security boundary.
