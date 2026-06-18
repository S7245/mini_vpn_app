# FINDINGS — Rust core → native Swift event stream over UniFFI

Friction log for spec §7.1 (option C: shared Rust core + thin native UI). This
is the **primary** deliverable; the demo is secondary. Measured 2026-06-16 on
macOS (Darwin 25.0.0, arm64), Rust 1.95.0, Swift 6.2, **uniffi 0.31.1**.

The demo ran clean end to end. Actual stdout:

```
== connect ==
[MAIN] state: connecting
[MAIN] state: connected
[MAIN] stats: up_bps=128000 down_bps=940000 up_bytes=64000 down_bytes=480000
[MAIN] log(info): tunnel established
[bg] stats: up_bps=128000 down_bps=940000 up_bytes=128000 down_bytes=960000
[bg] stats: up_bps=128000 down_bps=940000 up_bytes=192000 down_bytes=1440000
[bg] stats: up_bps=128000 down_bps=940000 up_bytes=256000 down_bytes=1920000
== disconnect ==
[MAIN] state: disconnected
[MAIN] log(info): disconnected
done
```

This matches the Swift `MockControlService` oracle exactly (same connect
sequence, same cumulative byte math: up += 64_000, down += 480_000 per tick).

---

## 1. Step count / setup friction

From zero to a running Rust→Swift live event stream: **4 files authored, 3
commands.**

Files authored (hand-written, ~210 LOC total):
1. `Cargo.toml` — crate config (`crate-type` triple + `uniffi` dep with `cli`
   feature + the `uniffi-bindgen` bin target).
2. `src/lib.rs` — `setup_scaffolding!()`, two `#[derive(uniffi::Enum)]`, the
   `#[uniffi::export(with_foreign)]` trait, the `#[derive(uniffi::Object)]` +
   `#[uniffi::export] impl`.
3. `src/bin/uniffi-bindgen.rs` — 3-line shim (`uniffi::uniffi_bindgen_main()`).
4. `Sources/main.swift` — the consumer.

Commands (codified in `run.sh`):
1. `cargo build`
2. `cargo run --bin uniffi-bindgen -- generate --library
   target/debug/libminivpn_ffi.dylib --language swift --out-dir generated`
3. `swiftc … generated/minivpn_ffi.swift Sources/main.swift -o demo`

Verdict: **low setup friction.** Proc-macro mode worked with zero UDL files.
The only non-obvious piece is the `uniffi-bindgen` bin shim, which the docs do
call out. Library-mode generation (point the generator at the built `.dylib`
rather than at source) Just Worked — no `--config`, no `--crate` flag needed; it
read the metadata embedded in the dylib.

## 2. Threading — THE key finding

`on_event` arrives on **whatever thread calls it in Rust. There is no automatic
hop to the Swift main thread.** Proven directly by tagging each line with
`Thread.isMainThread`:

- The synchronous connect-sequence events (connecting / connected / first stats
  / "tunnel established") print `[MAIN]` — they ran on the thread that called
  `service.connect()`, which here was the main thread.
- The 1s ticker stats print `[bg]` — they ran on the Rust `std::thread` the
  service spawned. UniFFI lowered the call straight through to the Swift
  closure on that foreign-invoked thread.

Implication for Phase 2 (binding to SwiftUI `@MainActor @Published`): there is a
**mandatory MainActor hop** for any event that originates off the Rust ticker
thread. The Swift observer's `onEvent` must NOT touch `@MainActor` state
directly; it has to bounce via `Task { @MainActor in … }` / `await
MainActor.run` / `DispatchQueue.main.async`. This is the same shape the Swift
`MockControlService` already implies (its `AsyncStream` consumer hops to the VM
on MainActor), so the contract is unchanged — but the hop is now **non-optional**
and on the hot path (one per stats tick). Cost is a per-event enqueue onto the
main queue; trivial at 1 Hz, worth a glance if stats ever go to e.g. 60 Hz.

## 3. Async / cancellation

The ticker is a plain `std::thread` gated on an `AtomicBool` stop-flag held in a
`Mutex`. `disconnect()` sets the flag, `take()`s the `JoinHandle`, and `join()`s
it before emitting the final state — so the thread is provably stopped before
"disconnected" is reported, and there is no event after `done`. Clean.

Rough edges:
- **No async on the boundary in this spike.** I used a raw OS thread, not
  tokio/`async fn`. UniFFI 0.31 *does* support `async fn` exports (backed by a
  foreign async runtime), but that's a second integration layer (futures +
  foreign executor) I deliberately didn't pull in — the callback-interface
  push model doesn't need it. If the real core is tokio-based, expect extra
  friction wiring the runtime; not measured here. **Flagged for §7.1.**
- The stop-flag is hand-rolled. There's no UniFFI-level cancellation primitive
  for a fire-and-forget push stream — you own the thread lifecycle. Fine, but
  it's manual; easy to leak a thread if `disconnect` is forgotten (the
  `Drop`/`deinit` belt-and-braces the mock has would need replicating).
- One-second `sleep` means `disconnect` can wait up to ~1s for the `join`. The
  spike checks the stop-flag immediately after waking, so worst case is bounded;
  a real impl would want a condvar/channel with timeout instead of `sleep`.

## 4. Type-mapping friction

Mostly smooth; the boundary is value-semantic and the derives are terse.

- **Enum-of-structs flattening.** The Swift oracle nests `TrafficStats` /
  `LogLine` structs inside `ControlEvent`. Across UniFFI I inlined those fields
  into the enum variants (`Stats { up_bps, down_bps, … }`, `Log { level,
  message }`). UniFFI *can* represent nested records, but inlining kept the
  variant count low and avoided extra `Record` types. Net effect: the Swift enum
  is `.stats(upBps:downBps:…)` instead of `.stats(TrafficStats)` — a cosmetic
  divergence from the oracle, re-nestable in a thin Swift adapter if Phase 2
  wants exact parity.
- **`i64` everywhere.** The Swift oracle uses `Int` (64-bit on arm64); UniFFI
  has no bare `Int`, so I used `i64` → Swift `Int64`. A one-line `Int(…)` cast
  at the adapter if exact-type parity matters. Minor.
- **`snake_case` → `camelCase`.** Rust `on_event`/`up_bps` become Swift
  `onEvent`/`upBps` automatically. Expected, no friction, but worth noting the
  Swift-side names differ from Rust source.
- **Callback interface naming.** `#[uniffi::export(with_foreign)] trait
  EventObserver` generates a Swift **protocol** `EventObserver` (good) plus an
  `EventObserverImpl` class. The `with_foreign` attribute is the bit you must
  remember — without it the trait is export-only (Rust→Rust), not implementable
  from Swift. Easy to miss; the compiler error if you forget is not obvious.
- **`Arc<dyn EventObserver>` constructor + `self: Arc<Self>` methods.** The
  object's exported methods take `self: Arc<Self>` and the constructor takes
  `Arc<dyn EventObserver>`. This is the idiomatic UniFFI-object shape and maps
  to a clean Swift `ControlService(observer:)` / `.connect()` / `.disconnect()`.
  No friction once you know to reach for `Arc`.

## 5. Build / link friction

The exact `swiftc` line that worked (links the **static** `.a`):

```sh
swiftc \
  -I generated \
  -L target/debug \
  -lminivpn_ffi \
  -Xcc -fmodule-map-file=generated/minivpn_ffiFFI.modulemap \
  generated/minivpn_ffi.swift \
  Sources/main.swift \
  -o demo
```

What was painful / non-obvious (each cost an iteration):
1. **The generated `minivpn_ffi.swift` must be compiled, not just imported.**
   UniFFI emits three artifacts: the C header, a modulemap, and a *Swift* file
   (`minivpn_ffi.swift`) that is the actual typed API. First attempt only
   `-import-objc-header`'d the `.h` and got "cannot find type 'EventObserver'" —
   the Swift wrapper types live in the `.swift` file. You compile that file
   **alongside** your own sources.
2. **The FFI clang module must be fed via `-Xcc -fmodule-map-file=…`.** The
   generated Swift does `#if canImport(minivpn_ffiFFI) / import minivpn_ffiFFI`.
   Just putting the modulemap on `-I` was not enough — Swift didn't find the
   raw FFI symbols (`uniffi_minivpn_ffi_fn_*` "cannot find in scope"). Passing
   the modulemap explicitly to the clang importer fixed it. This is the single
   least-obvious step in the whole pipeline.
3. **Static `.a` linked with zero extra system libs.** No `-lSystem`,
   `-framework Security`, `pthread`, rpath, or `DYLD_LIBRARY_PATH` needed — the
   Rust staticlib bundles std, and Swift's driver pulled the rest. Picking the
   `.a` over the `.dylib` sidestepped all runtime dylib-path pain (no `@rpath`,
   no `install_name_tool`). The `.a` is large (~150 MB debug) but that's debug
   bloat, not a real cost.

For Phase 2 / Xcode: this CLI link line does **not** translate 1:1 to an Xcode
target. xcframework packaging + the modulemap-as-clang-module dance is the
build-system tax that's still **unmeasured** — flagged for §7.1.

## 6. Bottom line

**Rust core → native Swift over FFI is light: ~4 files / 3 commands / ~210 LOC
to a clean live push stream, proc-macro only, no UDL, static-link with zero
system-lib fiddling.** The one genuine gotcha is the build glue — you must
*compile* the generated `.swift` and feed the FFI modulemap via `-Xcc
-fmodule-map-file`; everything else is mechanical.

**Phase 2 (MainActor binding) looks tractable but NOT free: the threading model
forces a mandatory main-thread hop** because callbacks fire on the Rust thread
that emits them (proven: ticker events arrive off-main). That's a known,
boilerplate-able pattern (`Task { @MainActor in … }` in the observer), so I'd
call it **low-risk**. The two things still unmeasured and worth de-risking
before betting on option C: (a) the **Xcode/xcframework** build integration vs
this raw `swiftc` line, and (b) wiring a real **tokio/async** core through the
boundary, which adds a foreign-executor layer this spike intentionally skipped.

---

## 7. Phase 2 — xcframework + SwiftUI (build tax + MainActor binding)

Measured 2026-06-16. Built `MiniVPNFFI.xcframework` from the release static lib,
linked it into a SwiftUI app via xcodegen, smoke-built with `xcodebuild`
(`** BUILD SUCCEEDED **`), and launched the app to confirm the live
Rust → FFI → MainActor → `@Published` path. This resolves remaining unknown (a).

### Result — the binding works, on the main actor

The SwiftUI `@MainActor` model received the full Rust stream
(connecting → connected → log → 1 Hz stats) and **every event applied with
`isMain=true` (10/10 lines)** — the `Task { @MainActor in … }` hop in the
observer behaves exactly as Phase 1 predicted, and `@Published` down/up bytes
updated live from the Rust ticker. Captured stdout:

```
[apply isMain=true] state(state: ...connecting)
[apply isMain=true] state(state: ...connected)
[apply isMain=true] stats(upBps: 128000, downBps: 940000, upBytes: 64000, downBytes: 480000)
[apply isMain=true] log(level: "info", message: "tunnel established")
[apply isMain=true] stats(... upBytes: 128000, downBytes: 960000)
[apply isMain=true] stats(... upBytes: 192000, downBytes: 1440000)
[apply isMain=true] stats(... upBytes: 256000, downBytes: 1920000)
```

### xcframework / xcodebuild friction (the 3 real things)

1. **modulemap must be renamed to `module.modulemap`.** UniFFI emits
   `minivpn_ffiFFI.modulemap`; `xcodebuild -create-xcframework -headers <dir>`
   only picks up a file literally named `module.modulemap` (inner
   `module minivpn_ffiFFI { … }` unchanged). One `cp`. Without it the clang
   module isn't found and the generated Swift's `import minivpn_ffiFFI` fails.
2. **A static-lib xcframework links cleanly via xcodegen** with just
   `dependencies: [{ framework: ../MiniVPNFFI.xcframework, embed: false }]` —
   xcodegen set the framework/header search paths; no manual flags, no rpath
   (static), no embedding.
3. **The generated `.swift` is a SOURCE, not part of the framework.** You add
   `../generated/minivpn_ffi.swift` to the app target's sources; the xcframework
   provides only the C/FFI clang module, and the typed Swift API compiles into
   the app.

### Incidental (not FFI)

- One macOS-version slip in my own view code (`onChange(of:_:)` two-param form
  is macOS 14+; target is 13 → one-line revert to the single-param form). Pure
  SwiftUI, nothing to do with the boundary.
- `setvbuf(stdout, nil, _IONBF, 0)` in the App init so a headless 4 s launch
  flushes logs; `SWIFT_VERSION 5.0` so the UniFFI-generated Swift isn't held to
  strict-concurrency errors (matches macos-app/Core's tools mode).

### Bottom line — Xcode build tax for option C

**Low and mechanical.** xcframework + xcodebuild is ~3 steps over the CLI (one
modulemap rename, `-create-xcframework`, one xcodegen dependency line) and Just
Worked; the MainActor binding is confirmed correct in a real SwiftUI app.
**Option C's UI-over-FFI path is now de-risked end to end on macOS.** Remaining:
(b) tokio/async on the boundary (foreign-executor layer), and — for production —
a universal/CI build of the xcframework (this spike is arm64-only by choice).

---

## 8. Phase 3 — tokio/async boundary + Android (Kotlin) reach

Measured 2026-06-16. Resolves remaining unknown (b), and adds the first
Android-side data point — Android is now the confirmed second platform, so the
spec §7.1 review gate is triggered and these spikes are its evidence.

### tokio / async over FFI — works, light

- Wiring: add the `tokio` dep + the `uniffi` `tokio` feature + a second impl
  block tagged `#[uniffi::export(async_runtime = "tokio")]`. ~3 lines of config.
  UniFFI drives the exported futures on a tokio runtime (pulls in `async-compat`
  transitively), so they can use tokio primitives (`tokio::time::sleep`).
- Swift consumes async exports as native `await`:
  ```
  == await ping() ==
  ping -> pong (awaited on tokio runtime)
  == await streamTicks(count: 3) (tokio task -> FFI callback) ==
  [bg] stats(... upBytes: 64000 ...)
  [bg] stats(... upBytes: 128000 ...)
  [bg] stats(... upBytes: 192000 ...)
  stream done
  ```
  `ping()` is a request/response future; `streamTicks()` pushes events over the
  callback from inside a tokio async fn. Both work.
- Threading is unchanged from Phase 1: callback-delivered events arrive on a
  tokio worker thread (`[bg]`), so the same mandatory MainActor/main-dispatcher
  hop applies. Async return values resolve back into the Swift `await`
  continuation normally.
- **Additive & non-breaking:** the Phase 1/2 sync path is untouched; re-verified
  after the change — Phase 1 CLI still streams, Phase 2 app still
  `** BUILD SUCCEEDED **` + `isMain=true`. (Gotcha: the shared `generated/` dir
  is overwritten by whichever phase runs last, so after Phase 3 you must re-run
  `build-phase2.sh` to rebuild the xcframework in lockstep — spike hygiene, not
  a C concern.)
- Bottom line: **a tokio-based core over FFI is low-friction.**

### Android (Kotlin) reach — bindings generate; full build needs a toolchain

- `uniffi-bindgen --language kotlin` produced a 2057-line `minivpn_ffi.kt` with
  the same shapes: `class ControlService`, `interface EventObserver`,
  `sealed class ControlEvent`, and the async exports mapped to Kotlin
  `suspend fun`s (callback interface → Kotlin interface). **The same Rust core
  yields an idiomatic Kotlin API for free** — no second logic implementation.
- **NOT measured (toolchain absent on this machine):** no android rust targets
  (`aarch64-linux-android` …), no NDK (`ANDROID_NDK_HOME` unset), no
  Gradle/kotlinc. A real Android build additionally needs: install android rust
  targets + NDK, cross-compile a `.so` per ABI, a Gradle module depending on
  `net.java.dev.jna` (the UniFFI Kotlin runtime), and a coroutine main-dispatcher
  hop (analogous to the Swift MainActor hop). That is the next spike if C is
  chosen, and it needs Android Studio/NDK installed.

### Bottom line for §7.1

C's portable-core mechanic is de-risked on the **producer** side (Rust core:
sync callbacks + tokio/async, both light) and the **Apple consumer** side end to
end (xcframework + SwiftUI + MainActor). The **Android consumer** is confirmed
reachable at the binding level (Kotlin generates cleanly, async → coroutines)
but its full build/runtime tax (NDK cross-compile + Gradle/JNA + coroutine
dispatch) is unmeasured pending an Android toolchain. Net: **C is technically
viable for an Apple + Android footprint**; the real remaining costs to weigh in
the review are the Android build/CI setup and the per-platform network-extension
不可避税 (`VpnService`) — neither is an FFI problem.

---

## 9. Phase 4 — Android (Kotlin) consumer RUN on the host JVM

Measured 2026-06-17. Phase 3 *generated* Kotlin bindings; Phase 4 actually
*runs* them. No Android emulator/NDK is set up, so the UniFFI-generated Kotlin
ran on the host JVM (OpenJDK 17) with JNA loading the Rust **darwin** dylib. The
Kotlin code path — JNA load, callback interface, sealed-class enum, and async
exports as `suspend fun`s — is identical to Android; only the native target
differs (`.so` vs `.dylib`).

### Setup friction (worth recording)

- **`brew install kotlin` FAILED** — not kotlin itself (its bottle downloaded)
  but its `openjdk` dependency download errored (`ghcr.io` HTTP/2
  PROTOCOL_ERROR). Worked around by downloading the standalone
  `kotlin-compiler-2.0.21.zip` and running it against the **system OpenJDK 17**.
  Data point: brew's bundled-JDK dependency is a flaky/heavy path; the
  standalone compiler + an existing JDK is lighter and avoided it.
- Runtime deps are plain Maven Central jars: `jna 5.14.0` (1.9 MB) +
  `kotlinx-coroutines-core-jvm 1.8.1` (1.5 MB). On real Android these are Gradle
  deps (JNA ships an Android artifact).

### Result — ran clean

```
== sync connect (callback stream) ==
[main]     State(state=CONNECTING)
[main]     State(state=CONNECTED)
[main]     Stats(... upBytes=64000 ...)
[main]     Log(level=info, message=tunnel established)
[Thread-0] Stats(... upBytes=128000 ...)
[Thread-1] Stats(... upBytes=192000 ...)
[main]     State(state=DISCONNECTED)
== await ping() ==          ping -> pong (awaited on tokio runtime)
== await streamTicks(3u) == (3 stats)  ->  done
```

- The callback `interface EventObserver`, `sealed class ControlEvent`,
  `enum class ConnectionState`, the sync methods, AND the tokio `suspend fun`s
  (`ping`, `streamTicks`) all work from Kotlin. `await ping()` drove the Rust
  tokio future and resumed the coroutine with the returned value.
- Threading mirrors the Swift finding: the std::thread ticker callbacks arrive
  on JNA worker threads (`Thread-0/1`); tokio async results resume on the
  calling coroutine context (`main`). So Android needs the same dispatcher hop
  (`withContext(Dispatchers.Main)` / a main dispatcher) for callback-delivered
  events that touch UI — the analogue of the Swift MainActor hop.

### Cross-compile to Android `.so` — DONE ✅

The Rust core cross-compiles to a real Android `.so`:

```
android-libs/arm64-v8a/libminivpn_ffi.so:
  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked
```

The same tokio/async core builds for `aarch64-linux-android` (API 24) via
`cargo ndk` in ~90 s. Steps: android rust targets (installed) + `cargo-ndk 4.1.2`
+ an NDK; then `./build-android-so.sh`.

Two real friction points worth recording (neither is a C risk):
- **`sdkmanager "ndk;27.2.12479018"` repeatedly failed** — the r27c download
  truncated at ~33% then `Error on ZipFile unknown archive`, on two attempts
  (not disk — 129 GB free on the retry). Worked around by downloading the NDK
  **directly** from `dl.google.com` (`android-ndk-r25c-darwin.zip`, 717 MB) with
  `curl -C - --retry` (resume survived a slow ~280 KB/s link), verifying the zip,
  and pointing `ANDROID_NDK_HOME` at it. Takeaway: prefer a direct, resumable NDK
  download over `sdkmanager` on a flaky link.
- **`cargo-ndk` 4.x: the API-level flag is `--platform N`, NOT `-p N`** (`-p` is
  cargo's `--package`, so `-p 24` panics with `unknown package: 24`).

### On-device run (Phase 4c) — DONE ✅, ran on a real Android emulator

Built a minimal Gradle Android app (`AndroidApp/`) bundling the cross-compiled
arm64 `.so` (in `jniLibs/arm64-v8a`) + the generated Kotlin + JNA(aar) +
coroutines, installed it on the existing **arm64** AVD (`Medium_Phone_API_36.0`,
booted headless), launched it, and captured the `SPIKE` logcat — the full Rust
core event stream running ON Android:

```
== connect (callback stream) ==
[main]     State(state=CONNECTING)
[main]     State(state=CONNECTED)
[main]     Stats(... upBytes=64000 ...)
[main]     Log(level=info, message=tunnel established)
[Thread-2] Stats(... upBytes=128000 ...)
[Thread-3] Stats(... upBytes=192000 ...)
[main]     State(state=DISCONNECTED)
== await ping() ==          ping -> pong (awaited on tokio runtime)
== await streamTicks(3u) == (3 stats)  ->  == done ==
```

So on the device: JNA loaded the arm64 `.so`, the callback interface fired
(ticker stats on Rust `Thread-2/3`, i.e. background — same dispatcher-hop need),
and the tokio `suspend fun`s (`ping`, `streamTicks`) drove coroutines correctly.
**Identical behaviour to the Swift app and the host-JVM run.**

Android build friction worth recording (network, not design):
- **AGP auto-installs `build-tools;34.0.0` by default and that SDK download hit
  the same flaky-link ZipFile corruption** as the NDK. Fix: pin
  `buildToolsVersion = "35.0.1"` (an already-installed version) so AGP never
  downloads it. (First `assembleDebug` still took ~13 min downloading AGP + deps.)
- JNA must be the **`@aar`** artifact on Android (`net.java.dev.jna:jna:5.14.0@aar`)
  — it bundles JNA's own native dispatch `.so` per ABI; the plain jar won't load.
- Used a standalone Gradle distribution (8.10.2) directly — no wrapper jar needed.

### Bottom line

**The Kotlin/UniFFI consumer path is proven to RUN on real Android**, not just
generate or run on the JVM. With
Phases 1–4, option C is de-risked across: the producer (Rust core — sync
callbacks + tokio/async), the Apple consumer (SwiftUI + xcframework + MainActor),
and the Android consumer mechanics (Kotlin + JNA + coroutines + suspend on the
JVM). The remaining Android-specific work is purely build/packaging (NDK
cross-compile + Gradle + emulator) — well-trodden and toolchain-gated, not a
design risk — plus the non-FFI `VpnService` native tax.

