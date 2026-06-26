//! THROWAWAY SPIKE — minivpn_ffi
//!
//! Proves a Rust core can push a live async event stream into a native Swift
//! consumer over UniFFI. Shapes mirror the Swift `MiniVPNCore` ControlService
//! oracle (see macos-app/Core/.../Services/{ControlService,MockControlService}.swift)
//! so this is "same contract, driven from Rust".
//!
//! Mock behaviour mirrors MockControlService:
//!   connect:    State(Connecting) -> State(Connected) -> one Stats -> Log(info,"tunnel established")
//!               then every 1s a Stats with cumulative bytes (up += 64_000, down += 480_000;
//!               up_bps 128_000, down_bps 940_000)
//!   disconnect: stop ticker -> State(Disconnected) -> Log(info,"disconnected")

use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::thread::JoinHandle;

uniffi::setup_scaffolding!();

/// Mirrors Swift `ConnectionState`.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Error,
}

/// Mirrors Swift `ControlEvent` (a flattened union of state/stats/log/error).
/// Swift's oracle nests TrafficStats/LogLine structs; across the FFI boundary
/// we inline the fields into the enum variants — see FINDINGS.md (type mapping).
#[derive(Debug, Clone, uniffi::Enum)]
pub enum ControlEvent {
    State {
        state: ConnectionState,
    },
    Stats {
        up_bps: i64,
        down_bps: i64,
        up_bytes: i64,
        down_bytes: i64,
    },
    Log {
        level: String,
        message: String,
    },
    Error {
        detail: String,
    },
}

/// UniFFI callback interface. Swift implements this; Rust calls into it.
/// `Send + Sync` because the ticker thread invokes `on_event` off the caller's
/// thread.
#[uniffi::export(with_foreign)]
pub trait EventObserver: Send + Sync {
    fn on_event(&self, event: ControlEvent);
}

struct TickerState {
    up_bytes: i64,
    down_bytes: i64,
    stop: Arc<AtomicBool>,
    handle: Option<JoinHandle<()>>,
}

/// Mirrors Swift `ControlService`. Constructed with the foreign observer.
#[derive(uniffi::Object)]
pub struct ControlService {
    observer: Arc<dyn EventObserver>,
    inner: Mutex<TickerState>,
}

fn next_stats(s: &mut TickerState) -> ControlEvent {
    s.up_bytes += 64_000;
    s.down_bytes += 480_000;
    ControlEvent::Stats {
        up_bps: 128_000,
        down_bps: 940_000,
        up_bytes: s.up_bytes,
        down_bytes: s.down_bytes,
    }
}

#[uniffi::export]
impl ControlService {
    /// Constructor — takes the foreign observer (Swift object boxed as Arc<dyn>).
    #[uniffi::constructor]
    pub fn new(observer: Arc<dyn EventObserver>) -> Arc<Self> {
        Arc::new(Self {
            observer,
            inner: Mutex::new(TickerState {
                up_bytes: 0,
                down_bytes: 0,
                stop: Arc::new(AtomicBool::new(false)),
                handle: None,
            }),
        })
    }

    /// connect: emit the deterministic connect sequence, then spawn the 1s ticker.
    pub fn connect(self: Arc<Self>) {
        let obs = self.observer.clone();
        obs.on_event(ControlEvent::State {
            state: ConnectionState::Connecting,
        });
        obs.on_event(ControlEvent::State {
            state: ConnectionState::Connected,
        });

        let first_stats = {
            let mut s = self.inner.lock().unwrap();
            next_stats(&mut s)
        };
        obs.on_event(first_stats);
        obs.on_event(ControlEvent::Log {
            level: "info".to_string(),
            message: "tunnel established".to_string(),
        });

        // Start the ticker thread. A fresh stop-flag per connect so a
        // reconnect after disconnect works cleanly.
        let stop = Arc::new(AtomicBool::new(false));
        let this = self.clone();
        let stop_for_thread = stop.clone();
        let handle = std::thread::spawn(move || {
            while !stop_for_thread.load(Ordering::Relaxed) {
                std::thread::sleep(std::time::Duration::from_secs(1));
                if stop_for_thread.load(Ordering::Relaxed) {
                    break;
                }
                let ev = {
                    let mut s = this.inner.lock().unwrap();
                    next_stats(&mut s)
                };
                this.observer.on_event(ev);
            }
        });

        let mut s = self.inner.lock().unwrap();
        // Replace any prior ticker (defensive; mirrors mock's old?.cancel()).
        s.stop.store(true, Ordering::Relaxed);
        s.stop = stop;
        s.handle = Some(handle);
    }

    /// disconnect: stop the ticker thread, then emit Disconnected + log.
    pub fn disconnect(self: Arc<Self>) {
        let handle = {
            let mut s = self.inner.lock().unwrap();
            s.stop.store(true, Ordering::Relaxed);
            s.handle.take()
        };
        if let Some(h) = handle {
            let _ = h.join();
        }
        self.observer.on_event(ControlEvent::State {
            state: ConnectionState::Disconnected,
        });
        self.observer.on_event(ControlEvent::Log {
            level: "info".to_string(),
            message: "disconnected".to_string(),
        });
    }
}

// --- Phase 3: tokio/async across the FFI boundary ---------------------------
//
// Measures the "foreign-executor layer" unknown flagged in FINDINGS §6: how
// much friction to expose a tokio-based async core over UniFFI and consume it
// from Swift `await`. `async_runtime = "tokio"` (requires uniffi's `tokio`
// feature) tells UniFFI to drive these futures on a tokio runtime, so they can
// use tokio primitives (`tokio::time::sleep`). Additive — the sync path above
// (Phase 1/2) is untouched.
#[uniffi::export(async_runtime = "tokio")]
impl ControlService {
    /// Async request/response: awaits a tokio primitive, returns a value.
    /// Swift consumes it as `let s = await service.ping()`.
    pub async fn ping(&self) -> String {
        tokio::time::sleep(std::time::Duration::from_millis(150)).await;
        "pong (awaited on tokio runtime)".to_string()
    }

    /// A tokio-driven event burst: pushes `count` stats ticks over the FFI
    /// callback from inside a tokio async fn (not a std::thread) — the shape a
    /// real tokio-based core would use. Swift: `await service.streamTicks(count: 3)`.
    pub async fn stream_ticks(&self, count: u32) {
        for _ in 0..count {
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            let ev = {
                let mut s = self.inner.lock().unwrap();
                next_stats(&mut s)
            };
            self.observer.on_event(ev);
        }
    }
}
