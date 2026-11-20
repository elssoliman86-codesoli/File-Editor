# ADR-003: Working copies and SAF exports

- Status: accepted.
- Context: The original file must not be corrupted and broad storage permissions are forbidden.
- Options: App-private files only (poor interoperability), MANAGE_EXTERNAL_STORAGE (rejected), SAF plus private working copies.
- Decision: Import into an app-private workspace; edit a separate payload; export with ACTION_CREATE_DOCUMENT; stream back through ContentResolver and compare SHA-256.
- Reasons: No broad storage permission, no accidental original overwrite, provider-independent read-back verification.
- Trade-offs: Importing needs temporary storage. Large-file streaming/Rope is not yet implemented, so the current import limit is 64 MB.
- Exit plan: Add FileChannel-backed random access and a Piece Table before increasing the large-file limit.
