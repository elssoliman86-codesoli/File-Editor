# Environment report

**Inspection date:** 2026-11-20 (UTC+2).

## Local Android phone / Termux

| Component | Observed result |
|---|---|
| OS | Linux `5.10.136-android12-9-00021-g821df8f5bd36`, Android, `aarch64` |
| Flutter / Dart | Not installed |
| Java / Gradle | Not installed |
| Android SDK / adb | `ANDROID_HOME` and `ANDROID_SDK_ROOT` are unset; SDK and adb not installed |
| Git | Not installed in Termux |
| Python | CPython 3.14.10 |
| Internet | HTTP checks to Flutter releases and pub.dev returned 200 |
| External validators | qpdf, Poppler, LibreOffice, MuPDF and Tesseract not installed |
| Free storage | Approximately 3.3 GB; insufficient margin for a local Flutter/Android SDK build |

The local environment therefore cannot run Flutter tests or produce a trustworthy APK. No command output was fabricated.

## Build environment selected

GitHub Actions (`ubuntu-latest`, x86_64) will run the pinned stable SDK and Android build:

- Flutter **3.50.1**, stable revision `ae9b586f34a8443573f82ef57c3bf914a908cbf7`.
- Dart **3.14.0** (bundled with that Flutter release).
- Java 17 (Temurin).
- Android `compileSdk = 36`, `targetSdk = 36`, `minSdk = 24`.

Flutter's official release feed was queried on 2026-11-20. Google Play's target API page states that, in 2026, new apps and updates must target Android 16 / API 36 or higher. minSdk 24 covers Android 7.0+ while PDFium and PDFBox-Android remain compatible.

## What can and cannot be verified

- Unit tests, pure Dart document conversion, static analysis and APK/AAB compilation are suitable for CI.
- UI widget tests do not prove Android SAF behavior, real camera operation, physical printing, IME behavior on every keyboard, or rendering parity with Microsoft Word.
- Device-only tests are listed in `docs/TEST_REPORT.md` as **not run** unless a tool result proves otherwise.
- The APK is a CI debug-signed artifact for direct evaluation. It is not a Play Store production-signed release and needs a private release keystore before distribution.
