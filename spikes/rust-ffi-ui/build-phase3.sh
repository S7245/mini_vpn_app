#!/usr/bin/env bash
# THROWAWAY SPIKE — Phase 3 runner.
# Build the tokio/async Rust core, regen bindings, compile + run a Swift async
# CLI (proves the foreign-executor layer), AND generate Kotlin bindings (the
# Android data point — generation only; full Android build needs NDK + android
# rust targets + Gradle/JNA, none installed here).
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/5 cargo build (tokio/async core) =="
cargo build >/dev/null
echo "   ok"

echo "== 2/5 regenerate Swift bindings =="
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libminivpn_ffi.dylib \
  --language swift --out-dir generated >/dev/null
echo "   ok"

echo "== 3/5 compile + run Swift async CLI =="
swiftc \
  -I generated \
  -L target/debug \
  -lminivpn_ffi \
  -Xcc -fmodule-map-file=generated/minivpn_ffiFFI.modulemap \
  generated/minivpn_ffi.swift \
  AsyncDemo/main.swift \
  -o async_demo
./async_demo

echo "== 4/5 generate Kotlin bindings (Android API shape; generation only) =="
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libminivpn_ffi.dylib \
  --language kotlin --out-dir generated-kotlin >/dev/null
echo "   generated-kotlin: $(ls generated-kotlin 2>/dev/null | tr '\n' ' ')"
find generated-kotlin -name '*.kt' -exec wc -l {} + | tail -1

echo "== 5/5 done =="
