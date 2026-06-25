#!/usr/bin/env bash
# Phase 2 one-shot Android build: cross-compile rust-core → arm64 .so, drop it
# into jniLibs, regenerate the UniFFI Kotlin bindings into the app sources, then
# assembleDebug. The .so and generated bindings are build products (gitignored);
# this script is their single source of truth.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUST_CORE="$(cd "$HERE/../rust-core" && pwd)"

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
NDK="$(ls -d "$SDK"/ndk/*/ 2>/dev/null | sort | tail -1)"
[ -n "$NDK" ] || { echo "no NDK under $SDK/ndk"; exit 1; }
# Run Gradle on Android Studio's bundled JBR (no system JDK assumed).
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"

JNILIBS="$HERE/app/src/main/jniLibs/arm64-v8a"
BINDINGS="$HERE/app/src/main/java"

echo "== 1/4 cross-compile rust-core arm64 .so (cargo-ndk) =="
( cd "$RUST_CORE" && ANDROID_NDK_HOME="$NDK" \
    cargo ndk -t arm64-v8a --platform 24 -o android-libs build --release 2>&1 | tail -3 )
file "$RUST_CORE/android-libs/arm64-v8a/libminivpn_core.so"

echo "== 2/4 copy .so into jniLibs =="
mkdir -p "$JNILIBS"
cp "$RUST_CORE/android-libs/arm64-v8a/libminivpn_core.so" "$JNILIBS/"

echo "== 3/4 regenerate UniFFI Kotlin bindings into app sources =="
mkdir -p "$BINDINGS"
( cd "$RUST_CORE" && cargo build >/dev/null && cargo run --bin uniffi-bindgen -- generate \
    --library target/debug/libminivpn_core.dylib --language kotlin --out-dir "$BINDINGS" >/dev/null )
echo "   $(find "$BINDINGS/uniffi" -name '*.kt' | head -1)"

echo "== 4/4 gradlew assembleDebug =="
( cd "$HERE" && ./gradlew assembleDebug )
echo "APK: $(ls "$HERE"/app/build/outputs/apk/debug/*.apk 2>/dev/null)"
