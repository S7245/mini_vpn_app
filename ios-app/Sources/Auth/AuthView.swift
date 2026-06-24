import SwiftUI
import MiniVPNCore

/// Auth flow host: Login as root, Register pushed on top.
struct AuthView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            LoginView(auth: auth)
        }
    }
}
