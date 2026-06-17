#!/usr/bin/env bash
# THROWAWAY SPIKE — Phase 2 runner.
# release build -> regen bindings -> build xcframework -> xcodegen -> xcodebuild
# -> launch app ~4s and capture stdout (proves Rust->FFI->MainActor->@Published).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

echo "== 1/6 cargo build --release =="
cargo build --release >/dev/null
ls -lh target/release/libminivpn_ffi.a | awk '{print "   static lib:", $5}'

echo "== 2/6 regenerate Swift bindings (release lib) =="
cargo run --release --bin uniffi-bindgen -- generate \
  --library target/release/libminivpn_ffi.dylib \
  --language swift --out-dir generated >/dev/null
echo "   generated: $(ls generated | tr '\n' ' ')"

echo "== 3/6 assemble xcframework (static .a + headers w/ module.modulemap) =="
rm -rf MiniVPNFFI.xcframework Headers
mkdir -p Headers
cp generated/minivpn_ffiFFI.h Headers/
# Xcode looks for a module named exactly 'module.modulemap' in the headers dir.
cp generated/minivpn_ffiFFI.modulemap Headers/module.modulemap
xcodebuild -create-xcframework \
  -library target/release/libminivpn_ffi.a \
  -headers Headers \
  -output MiniVPNFFI.xcframework >/dev/null
echo "   built MiniVPNFFI.xcframework"

echo "== 4/6 xcodegen generate =="
cd "$ROOT/Phase2-App"
xcodegen generate >/dev/null
echo "   project generated"

echo "== 5/6 xcodebuild (smoke build) =="
xcodebuild -project SpikeFFIApp.xcodeproj -scheme SpikeFFIApp \
  -destination 'platform=macOS' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | tail -10

echo "== 6/6 launch app ~4s, capture MainActor-bound stream =="
APP=$(xcodebuild -project SpikeFFIApp.xcodeproj -scheme SpikeFFIApp \
  -destination 'platform=macOS' -configuration Debug \
  -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR =/{d=$3} / EXECUTABLE_PATH =/{e=$3} END{print d"/"e}')
echo "   binary: $APP"
( "$APP" 2>&1 & APID=$!; sleep 4; kill "$APID" 2>/dev/null; wait "$APID" 2>/dev/null ) \
  | grep -E "apply isMain" | head -8 || true
echo "== done =="
