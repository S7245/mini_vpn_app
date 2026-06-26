import SwiftUI
import MiniVPNCore

@main
struct MiniVPNiOSApp: App {
    // Single wiring point — swap the mocks for real backend ② / control ① here
    // later (one line each); views/view-models do not change.
    @StateObject private var auth = AuthViewModel(
        backend: MockBackendService(),
        store: UserDefaultsSessionStore()
    )
    private let backend: BackendService = MockBackendService()
    private let control: ControlService = MockControlService()

    var body: some Scene {
        WindowGroup {
            RootView(auth: auth, backend: backend, control: control)
        }
    }
}
