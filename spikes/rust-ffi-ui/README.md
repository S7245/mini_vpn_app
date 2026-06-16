# rust-ffi-ui spike (THROWAWAY)

A throwaway de-risking spike for spec §7.1 option C (shared Rust core + thin
native UI). It proves a Rust core can push a live async event stream
(state/stats/log) into a native Swift consumer over UniFFI, and records the real
friction in [`FINDINGS.md`](./FINDINGS.md) — the friction log is the primary
deliverable; the demo is secondary. Shapes mirror the Swift `MiniVPNCore`
`ControlService` oracle so this is "same contract, driven from Rust". Disposable
once §7.1 is decided.

**Run:** `./run.sh` (needs Rust 1.95 + `aarch64-apple-darwin`, Swift 6.2). It
builds the `minivpn_ffi` crate, generates Swift bindings via UniFFI in library
mode, compiles the Swift CLI in `Sources/main.swift` against the static lib, and
runs the demo — you should see connecting → connected → "tunnel established" →
~3 per-second stats ticks → disconnected → `done`, each line tagged with the
thread it arrived on.
