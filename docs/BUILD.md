# Reproducible build

## Requirements

- Linux x86_64 (CI uses `ubuntu-latest`).
- Flutter 3.50.1 stable / Dart 3.14.0.
- Java 17 and Android SDK platform/build-tools 36.
- Gradle 9.5.0, Android Gradle Plugin 9.3.1 and Kotlin 2.4.20. These match the app
  template of Flutter 3.50.1 (`gradle_utils.dart`); keep them in step when upgrading
  Flutter. `android/gradle.properties` carries the template's `android.newDsl=false`
  and `android.builtInKotlin=false` flags.
- `pubspec.lock` is committed. Run `flutter pub upgrade` deliberately instead of letting
  CI drift; dependencies use caret ranges, never exact pins, so pub can resolve them
  together with the Flutter SDK's own pinned packages (`test_api`, `intl`, `path`).

## Commands

```bash
bash tools/fetch_fonts.sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --no-fatal-infos
flutter test --coverage
(cd packages/docx_engine && dart pub get && dart test)   # likewise txt_engine
flutter build apk --debug
flutter build apk --debug --split-per-abi
```

Universal and ABI APKs appear under `build/app/outputs/flutter-apk/`. CI verifies signatures with `apksigner` and publishes `SHA256SUMS.txt`.

For a production release, configure your own keystore outside Git and an explicit release signing configuration. Do not commit `key.properties`, JKS files or passwords. The included `midadEvaluationSigning` Gradle property is only for explicit non-production evaluation signing.

## Offline/privacy

The application itself uses local storage and no analytics. Package resolution and native PDFium artifacts need network access at build time, not when editing documents.
