#!/usr/bin/env bash
# THROWAWAY SPIKE — Phase 4c: build the Android app (bundling the cross-compiled
# arm64 .so + generated Kotlin), boot the existing arm64 AVD headless, install,
# launch, and capture the "SPIKE" logcat showing the Rust event stream on Android.
# Prereqs: ./build-android-so.sh (produces the .so) and the Gradle distribution
# under AndroidApp/.gradle-dist (downloaded separately). Android SDK + an arm64
# AVD already present.
set -euo pipefail
cd "$(dirname "$0")/AndroidApp"

SDK="$HOME/Library/Android/sdk"; export ANDROID_SDK_ROOT="$SDK" ANDROID_HOME="$SDK"
GRADLE="$(ls -d .gradle-dist/gradle-*/bin/gradle 2>/dev/null | head -1)"
ADB="$SDK/platform-tools/adb"
AVD="${AVD:-Medium_Phone_API_36.0}"
[ -x "$GRADLE" ] || { echo "no gradle dist under .gradle-dist"; exit 1; }

echo "== 1/5 build debug APK (first run also downloads AGP + deps) =="
"$GRADLE" :app:assembleDebug --no-daemon --console=plain 2>&1 | tail -20
APK="app/build/outputs/apk/debug/app-debug.apk"
[ -f "$APK" ] || { echo "APK not built"; exit 1; }
echo "   APK: $(ls -lh "$APK" | awk '{print $5}')"

echo "== 2/5 boot emulator headless =="
"$SDK/emulator/emulator" -avd "$AVD" -no-window -no-snapshot -no-audio -no-boot-anim \
  -gpu swiftshader_indirect >/tmp/spike-emu.log 2>&1 &
EMUPID=$!
"$ADB" wait-for-device
n=0; until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] || [ $n -ge 80 ]; do sleep 3; n=$((n+1)); done
echo "   boot_completed=$("$ADB" shell getprop sys.boot_completed | tr -d '\r')"

echo "== 3/5 install =="
"$ADB" install -r "$APK" 2>&1 | tail -2

echo "== 4/5 launch + capture =="
"$ADB" logcat -c
"$ADB" shell am start -n com.spike.ffi/.MainActivity 2>&1 | tail -1
sleep 7
echo "== 5/5 SPIKE logcat (Rust -> FFI -> Kotlin on Android) =="
"$ADB" logcat -d -s SPIKE:I | sed 's/^.*SPIKE  *: //' | tail -25

echo "== cleanup: stop emulator =="
"$ADB" emu kill 2>/dev/null || kill "$EMUPID" 2>/dev/null || true
