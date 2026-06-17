import SwiftUI
import Foundation

// THROWAWAY SPIKE (Phase 2): a SwiftUI app whose live state is driven entirely
// by the Rust core over UniFFI. Proves the Rust event stream binds to
// @MainActor @Published with the mandatory main-thread hop (callbacks arrive on
// the Rust emitting thread — see FINDINGS.md §2).

/// Bridges the Rust callback (any thread) onto the main actor.
final class Observer: EventObserver {
    private let onMain: (ControlEvent) -> Void
    init(onMain: @escaping (ControlEvent) -> Void) { self.onMain = onMain }
    func onEvent(event: ControlEvent) {
        // Called on whatever Rust thread emits (ticker = background). Hop.
        let cb = onMain
        Task { @MainActor in cb(event) }
    }
}

@MainActor
final class SpikeModel: ObservableObject {
    @Published var state: ConnectionState = .disconnected
    @Published var upBytes: Int64 = 0
    @Published var downBytes: Int64 = 0
    @Published var lastLog: String = ""

    private var service: ControlService!

    init() {
        service = ControlService(observer: Observer(onMain: { [weak self] event in
            self?.apply(event)
        }))
    }

    func connect() { service.connect() }
    func disconnect() { service.disconnect() }

    func apply(_ event: ControlEvent) {
        // isMain MUST be true here — proves the hop landed on the main actor.
        print("[apply isMain=\(Thread.isMainThread)] \(event)")
        switch event {
        case .state(let s): state = s
        case .stats(_, _, let up, let down): upBytes = up; downBytes = down
        case .log(let level, let message): lastLog = "\(level): \(message)"
        case .error(let detail): state = .error; lastLog = "error: \(detail)"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = SpikeModel()
    @State private var on = false

    var body: some View {
        VStack(spacing: 12) {
            Text("State: \(String(describing: model.state))").font(.headline)
            Text("↓ \(model.downBytes) B    ↑ \(model.upBytes) B").monospacedDigit()
            Text(model.lastLog).font(.caption).foregroundStyle(.secondary)
            Toggle("Connect", isOn: $on)
                .onChange(of: on) { v in v ? model.connect() : model.disconnect() }
        }
        .frame(width: 340, height: 180)
        .padding()
        // Auto-connect on launch so a headless run shows the live stream.
        .task { on = true; model.connect() }
    }
}

@main
struct SpikeApp: App {
    init() {
        // Unbuffer stdout so a headless 4s launch captures the live stream
        // (a GUI app's stdout is block-buffered to a pipe otherwise).
        setvbuf(stdout, nil, _IONBF, 0)
    }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
