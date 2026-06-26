#!/usr/bin/env bash
# rust-core Phase 1 verify: cargo test (state machine) + generate Kotlin/Swift
# bindings + cross-compile the Android arm64 .so.
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/4 cargo test =="
cargo test 2>&1 | tail -6

echo "== 2/4 cargo build (host, for bindgen) =="
cargo build >/dev/null

echo "== 3/4 generate bindings =="
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libminivpn_core.dylib --language kotlin --out-dir generated-kotlin >/dev/null
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libminivpn_core.dylib --language swift  --out-dir generated-swift  >/dev/null
echo "   kotlin: $(find generated-kotlin -name '*.kt' | head -1)"
echo "   swift:  $(find generated-swift -name '*.swift' | head -1)"

echo "== 4/4 cross-compile Android arm64 .so =="
SDK="$HOME/Library/Android/sdk"
NDK="$(ls -d "$SDK"/ndk/*/ 2>/dev/null | sort | tail -1)"
[ -n "$NDK" ] || { echo "no NDK under $SDK/ndk"; exit 1; }
ANDROID_NDK_HOME="$NDK" cargo ndk -t arm64-v8a --platform 24 -o android-libs build --release 2>&1 | tail -3
file android-libs/arm64-v8a/libminivpn_core.so
