#!/usr/bin/env bash
# THROWAWAY SPIKE runner: build -> generate bindings -> compile Swift -> run.
# Reproduces the Rust core -> Swift event stream demo in one shot.
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/4 cargo build =="
cargo build

echo "== 2/4 generate Swift bindings (library mode) =="
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libminivpn_ffi.dylib \
  --language swift \
  --out-dir generated

echo "== 3/4 compile Swift CLI (links static .a; modulemap via -Xcc) =="
swiftc \
  -I generated \
  -L target/debug \
  -lminivpn_ffi \
  -Xcc -fmodule-map-file=generated/minivpn_ffiFFI.modulemap \
  generated/minivpn_ffi.swift \
  Sources/main.swift \
  -o demo

echo "== 4/4 run =="
./demo
