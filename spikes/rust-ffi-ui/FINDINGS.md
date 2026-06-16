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
