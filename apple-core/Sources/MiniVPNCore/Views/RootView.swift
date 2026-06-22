import SwiftUI

public struct RootView: View {
    @StateObject private var connection: ConnectionViewModel
    @StateObject private var nodes: NodeListViewModel
    @StateObject private var account: AccountViewModel

    public init(backend: BackendService, control: ControlService) {
        _connection = StateObject(wrappedValue: ConnectionViewModel(control: control))
        _nodes = StateObject(wrappedValue: NodeListViewModel(backend: backend))
        _account = StateObject(wrappedValue: AccountViewModel(backend: backend))
    }

    public var body: some View {
        TabView {
            ConnectionView(connection: connection).tabItem { Label("Connect", systemImage: "power") }
            NodeListView(model: nodes).tabItem { Label("Nodes", systemImage: "globe") }
            LogsView(connection: connection).tabItem { Label("Logs", systemImage: "text.alignleft") }
            SettingsView(account: account).tabItem { Label("Settings", systemImage: "gear") }
        }
        .frame(minWidth: 480, minHeight: 420)
        .onAppear { connection.start() }
    }
}
