import SwiftUI
import MiniVPNCore

@main
struct MiniVPNApp: App {
    // First cut: wire the MOCK services. Swapping to real ②/① later is a
    // one-line change here — the views/view-models do not change.
    private let backend: BackendService = MockBackendService()
    private let control: ControlService = MockControlService()

    var body: some Scene {
        WindowGroup {
            RootView(backend: backend, control: control)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("MiniVPN", systemImage: "shield") {
            RootView(backend: backend, control: control)
                .frame(width: 360, height: 420)
        }
        .menuBarExtraStyle(.window)
    }
}
