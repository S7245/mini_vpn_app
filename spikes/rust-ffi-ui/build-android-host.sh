#!/usr/bin/env bash
# THROWAWAY SPIKE — Phase 4a: run the UniFFI Kotlin consumer on the HOST JVM
# against the darwin dylib (proves the Kotlin/JNA/coroutine path that Android
# also uses; only the native target differs). Needs: kotlinc + the jars in
# KotlinHost/libs + target/debug/libminivpn_ffi.dylib (from build-phase1/3).
set -euo pipefail
cd "$(dirname "$0")"

LIBDIR="$(pwd)/target/debug"
KT="generated-kotlin/uniffi/minivpn_ffi/minivpn_ffi.kt"
CP="KotlinHost/libs/jna.jar:KotlinHost/libs/kotlinx-coroutines-core-jvm.jar"

[ -f "$LIBDIR/libminivpn_ffi.dylib" ] || { echo "missing dylib — run ./build-phase3.sh first"; exit 1; }
[ -f "$KT" ] || { echo "missing kotlin bindings — run ./build-phase3.sh first"; exit 1; }

echo "== compile (kotlinc) =="
kotlinc "$KT" KotlinHost/Main.kt -cp "$CP" -include-runtime -d KotlinHost/app.jar

echo "== run (java, JNA -> darwin dylib) =="
java -Djna.library.path="$LIBDIR" -cp "KotlinHost/app.jar:$CP" MainKt
