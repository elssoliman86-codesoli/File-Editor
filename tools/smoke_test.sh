#!/usr/bin/env bash
# Runs inside an Android emulator (see .github/workflows/android.yml).
set -u
PKG=com.elssoliman.midad
APK="${1:?apk path}"
fail=0
adb install -r "$APK" || exit 1
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 25
if [ -z "$(adb shell pidof "$PKG")" ]; then
  echo "::error::app is not running after launch"; adb logcat -d | tail -80; exit 1
fi
python3 tools/ui_dump.py "after launch"
(cd tools && python3 ui_flow.py) || { echo "::error::UI flow failed"; fail=1; }
adb logcat -d > /tmp/logcat.txt
if grep -E "FATAL EXCEPTION|Fatal signal" /tmp/logcat.txt; then
  echo "::error::native or Java crash detected"; fail=1
fi
grep -E "flutter|E/DartVM|Unhandled" /tmp/logcat.txt | tail -30
exit $fail
