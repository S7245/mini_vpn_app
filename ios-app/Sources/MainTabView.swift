import SwiftUI
import MiniVPNCore

/// Main shell after login: 3 tabs (Logs dropped on mobile). Connect/Nodes are
/// placeholders filled in M3/M4; Account here is a minimal stub carrying log-out
/// so the session-gate round-trip is verifiable now.
struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel
    let backend: BackendService
    @StateObject private var connection: ConnectionViewModel

    init(auth: AuthViewModel, backend: BackendService, control: ControlService) {
        self.auth = auth
        self.backend = backend
        _connection = StateObject(wrappedValue: ConnectionViewModel(control: control))
    }

    var body: some View {
        TabView {
            ConnectionView(connection: connection)
                .tabItem { Label("Connect", systemImage: "power") }
            placeholder("Nodes", "globe")
                .tabItem { Label("Nodes", systemImage: "globe") }
            accountStub
                .tabItem { Label("Account", systemImage: "person") }
        }
    }

    private func placeholder(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.secondary)
            Text("\(title) — coming soon").foregroundStyle(.secondary)
        }
    }

    private var accountStub: some View {
        VStack(spacing: 16) {
            Text("Account").font(.title2).fontWeight(.medium)
            Text("subscription + devices — coming soon").font(.footnote).foregroundStyle(.secondary)
            Button(role: .destructive) {
                Task { await auth.logout() }
            } label: {
                Text("Log out").frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            .padding(.horizontal, 24)
        }
    }
}
