//! minivpn_core — the GUI-shared control/business logic, exposed to native UIs
//! via UniFFI (Kotlin for Android now; Swift available for Apple later).
//!
//! Slice 1 (this file): the ① local-control `ControlService` — the connection
//! state machine + event stream, MOCK impl. Shapes mirror the Swift
//! `apple-core` ControlService (the reference oracle); productized from
//! `spikes/rust-ffi-ui`. Slice 2 (`backend`/`models` modules): the ②
//! BackendService (auth/nodes/subscription/devices), mock-decoding the same
//! `contracts/mock` fixtures — mirrors Swift `MockBackendService`.
//!
//! NOTE: this is the GUI control/business core. The data-plane VPN core lives
//! in the separate `mini_vpn` repo and is NOT touched here.

use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::thread::JoinHandle;

uniffi::setup_scaffolding!();

// Slice ② — backend control plane (auth / nodes / subscription / devices).
pub mod backend;
pub mod models;

/// Mirrors Swift `ConnectionState`.
#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Error,
}

/// Mirrors Swift `ControlEvent` (state/stats/log/error). TrafficStats/LogLine
/// are inlined into the variants across the FFI boundary (see spike FINDINGS).
#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum ControlEvent {
    State { state: ConnectionState },
    Stats { up_bps: i64, down_bps: i64, up_bytes: i64, down_bytes: i64 },
    Log { level: String, message: String },
    Error { detail: String },
}

/// Mirrors Swift `ControlCommand` (① local-control commands).
#[derive(Debug, Clone, PartialEq, uniffi::Enum)]
pub enum ControlCommand {
    Connect { node_id: String },
    Disconnect,
    SelectNode { node_id: String },
    Auto,
}

/// UniFFI callback interface. The native UI implements this; Rust pushes events.
/// `Send + Sync` because the ticker thread invokes it off the caller's thread —
/// the UI side hops to its main dispatcher (MainActor / Dispatchers.Main).
#[uniffi::export(with_foreign)]
pub trait EventObserver: Send + Sync {
    fn on_event(&self, event: ControlEvent);
}

struct Inner {
    up_bytes: i64,
    down_bytes: i64,
    stop: Arc<AtomicBool>,
    handle: Option<JoinHandle<()>>,
}

/// Mock ① ControlService — deterministic state machine mirroring Swift
/// `MockControlService`. connect/auto/selectNode → connecting → connected →
/// one stats → log; with `live_ticker`, then a stats every 1s. disconnect →
/// stop ticker → disconnected → log. A real transport will implement the SAME
/// exported interface later (mock→real swap, no UI change).
#[derive(uniffi::Object)]
pub struct ControlService {
    observer: Arc<dyn EventObserver>,
    live_ticker: bool,
    inner: Mutex<Inner>,
}

fn next_stats(inner: &mut Inner) -> ControlEvent {
    inner.up_bytes += 64_000;
    inner.down_bytes += 480_000;
    ControlEvent::Stats {
        up_bps: 128_000,
        down_bps: 940_000,
        up_bytes: inner.up_bytes,
        down_bytes: inner.down_bytes,
    }
}

#[uniffi::export]
impl ControlService {
    #[uniffi::constructor]
    pub fn new(observer: Arc<dyn EventObserver>, live_ticker: bool) -> Arc<Self> {
        Arc::new(Self {
            observer,
            live_ticker,
            inner: Mutex::new(Inner {
                up_bytes: 0,
                down_bytes: 0,
                stop: Arc::new(AtomicBool::new(false)),
                handle: None,
            }),
        })
    }

    /// ① local-control command entry point (mirrors Swift `send(_:)`).
    pub fn send(self: Arc<Self>, command: ControlCommand) {
        match command {
            ControlCommand::Connect { .. }
            | ControlCommand::Auto
            | ControlCommand::SelectNode { .. } => Self::start(self),
            ControlCommand::Disconnect => Self::stop(self),
        }
    }
}

// Private helpers — NOT a uniffi-export block (they take `Arc<Self>`, not a
// foreign-callable `&self`, so they must live outside `#[uniffi::export]`).
impl ControlService {
    fn start(this: Arc<Self>) {
        this.observer.on_event(ControlEvent::State { state: ConnectionState::Connecting });
        this.observer.on_event(ControlEvent::State { state: ConnectionState::Connected });
        let first = {
            let mut g = this.inner.lock().unwrap();
            next_stats(&mut g)
        };
        this.observer.on_event(first);
        this.observer.on_event(ControlEvent::Log {
            level: "info".to_string(),
            message: "tunnel established".to_string(),
        });

        if this.live_ticker {
            let stop = Arc::new(AtomicBool::new(false));
            let stop_for_thread = stop.clone();
            let svc = this.clone();
            let handle = std::thread::spawn(move || {
                while !stop_for_thread.load(Ordering::Relaxed) {
                    std::thread::sleep(std::time::Duration::from_secs(1));
                    if stop_for_thread.load(Ordering::Relaxed) {
                        break;
                    }
                    let ev = {
                        let mut g = svc.inner.lock().unwrap();
                        next_stats(&mut g)
                    };
                    svc.observer.on_event(ev);
                }
            });
            let mut g = this.inner.lock().unwrap();
            g.stop.store(true, Ordering::Relaxed); // retire any prior ticker
            g.stop = stop;
            g.handle = Some(handle);
        }
    }

    fn stop(this: Arc<Self>) {
        let handle = {
            let mut g = this.inner.lock().unwrap();
            g.stop.store(true, Ordering::Relaxed);
            g.handle.take()
        };
        if let Some(h) = handle {
            let _ = h.join();
        }
        this.observer.on_event(ControlEvent::State { state: ConnectionState::Disconnected });
        this.observer.on_event(ControlEvent::Log {
            level: "info".to_string(),
            message: "disconnected".to_string(),
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Collector(Arc<Mutex<Vec<ControlEvent>>>);
    impl EventObserver for Collector {
        fn on_event(&self, event: ControlEvent) {
            self.0.lock().unwrap().push(event);
        }
    }

    fn collect() -> (Arc<ControlService>, Arc<Mutex<Vec<ControlEvent>>>) {
        let events = Arc::new(Mutex::new(Vec::new()));
        let svc = ControlService::new(Arc::new(Collector(events.clone())), false);
        (svc, events)
    }

    #[test]
    fn connect_emits_connecting_connected_stats_log() {
        let (svc, events) = collect();
        svc.send(ControlCommand::Connect { node_id: "n1".to_string() });
        let e = events.lock().unwrap().clone();
        assert_eq!(e.len(), 4);
        assert_eq!(e[0], ControlEvent::State { state: ConnectionState::Connecting });
        assert_eq!(e[1], ControlEvent::State { state: ConnectionState::Connected });
        assert!(matches!(e[2], ControlEvent::Stats { up_bytes: 64_000, down_bytes: 480_000, .. }));
        assert!(matches!(&e[3], ControlEvent::Log { level, .. } if level == "info"));
    }

    #[test]
    fn auto_and_select_node_also_connect() {
        for cmd in [ControlCommand::Auto, ControlCommand::SelectNode { node_id: "n1".into() }] {
            let (svc, events) = collect();
            svc.send(cmd);
            let e = events.lock().unwrap().clone();
            assert_eq!(e[0], ControlEvent::State { state: ConnectionState::Connecting });
            assert_eq!(e[1], ControlEvent::State { state: ConnectionState::Connected });
        }
    }

    #[test]
    fn disconnect_emits_disconnected_and_log() {
        let (svc, events) = collect();
        svc.send(ControlCommand::Disconnect);
        let e = events.lock().unwrap().clone();
        assert_eq!(e[0], ControlEvent::State { state: ConnectionState::Disconnected });
        assert!(matches!(&e[1], ControlEvent::Log { .. }));
    }

    #[test]
    fn stats_accumulate_across_ticks() {
        // live_ticker off: drive next_stats directly to assert cumulative math.
        let events = Arc::new(Mutex::new(Vec::new()));
        let svc = ControlService::new(Arc::new(Collector(events.clone())), false);
        svc.clone().send(ControlCommand::Connect { node_id: "n".into() });
        svc.send(ControlCommand::Connect { node_id: "n".into() });
        let e = events.lock().unwrap().clone();
        // two connect bursts → second stats has doubled cumulative bytes
        let stats: Vec<_> = e.iter().filter_map(|ev| match ev {
            ControlEvent::Stats { up_bytes, down_bytes, .. } => Some((*up_bytes, *down_bytes)),
            _ => None,
        }).collect();
        assert_eq!(stats[0], (64_000, 480_000));
        assert_eq!(stats[1], (128_000, 960_000));
    }
}
