import SwiftUI
import MiniVPNCore

/// Session gate (FR-03): unauthenticated → Auth flow; authenticated → main tabs.
/// `auth.isAuthenticated` is restored from the persisted token on launch.
struct RootView: View {
    @ObservedObject var auth: AuthViewModel
    let backend: BackendService
    let control: ControlService

    var body: some View {
        if auth.isAuthenticated {
            MainTabView(auth: auth, backend: backend, control: control)
        } else {
            AuthView(auth: auth)
        }
    }
}
