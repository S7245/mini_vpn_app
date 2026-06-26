#!/usr/bin/env bash
# THROWAWAY SPIKE — Phase 4b: cross-compile the Rust core to an Android .so.
# The genuinely Android-specific build step (no emulator needed to prove it
# builds). Needs: android rust target (installed), cargo-ndk (installed), and an
# NDK under ~/Library/Android/sdk/ndk (installed via sdkmanager).
set -euo pipefail
cd "$(dirname "$0")"

SDK="$HOME/Library/Android/sdk"
NDK="$(ls -d "$SDK"/ndk/* 2>/dev/null | sort | tail -1)"
[ -n "$NDK" ] || { echo "no NDK under $SDK/ndk — run: sdkmanager 'ndk;27.2.12479018'"; exit 1; }
export ANDROID_NDK_HOME="$NDK"
echo "NDK: $ANDROID_NDK_HOME"

echo "== cross-compile cdylib for arm64-v8a (aarch64-linux-android, API 24) =="
cargo ndk -t arm64-v8a --platform 24 -o ./android-libs build --release 2>&1 | tail -10

echo "== produced .so =="
find android-libs -name '*.so' -exec ls -lh {} + 2>/dev/null
echo "== verify it is an Android aarch64 ELF =="
SO="$(find android-libs -name 'libminivpn_ffi.so' | head -1)"
file "$SO" 2>/dev/null || true
