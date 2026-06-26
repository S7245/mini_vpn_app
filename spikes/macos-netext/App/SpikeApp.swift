import SwiftUI

// Minimal container app: a button that installs + starts the tunnel. Compiles;
// installing/starting at runtime requires the NetworkExtension entitlement +
// provisioning profile (Apple Developer portal step). Here only to make the
// app-side NE surface concrete and compile-checked.
@main
struct SpikeNetExtApp: App {
    private let tunnel = TunnelManager()
    @State private var status = "idle"

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("MiniVPN NetExt spike").font(.headline)
                Text("status: \(status)").monospacedDigit()
                Button("Install + Connect") {
                    Task {
                        do {
                            try await tunnel.install()
                            try tunnel.connect()
                            status = "requested (needs NE entitlement to actually load)"
                        } catch {
                            status = "error: \(error.localizedDescription)"
                        }
                    }
                }
            }
            .frame(width: 360, height: 160)
            .padding()
        }
    }
}
