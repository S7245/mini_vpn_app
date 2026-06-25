import SwiftUI
import MiniVPNCore

/// Main shell after login: 3 tabs (Logs dropped on mobile). Connect/Nodes are
/// placeholders filled in M3/M4; Account here is a minimal stub carrying log-out
/// so the session-gate round-trip is verifiable now.
struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel
    let backend: BackendService
    @StateObject private var connection: ConnectionViewModel
    @StateObject private var nodes: NodeListViewModel
    @StateObject private var account: AccountViewModel

    init(auth: AuthViewModel, backend: BackendService, control: ControlService) {
        self.auth = auth
        self.backend = backend
        _connection = StateObject(wrappedValue: ConnectionViewModel(control: control))
        _nodes = StateObject(wrappedValue: NodeListViewModel(backend: backend))
        _account = StateObject(wrappedValue: AccountViewModel(backend: backend))
    }

    var body: some View {
        TabView {
            ConnectionView(connection: connection, nodes: nodes)
                .tabItem { Label("Connect", systemImage: "power") }
            NodeListView(model: nodes)
                .tabItem { Label("Nodes", systemImage: "globe") }
            AccountView(account: account, auth: auth)
                .tabItem { Label("Account", systemImage: "person") }
        }
    }
}
