import SwiftUI

public struct ConnectionView: View {
    @ObservedObject var connection: ConnectionViewModel
    public init(connection: ConnectionViewModel) { self.connection = connection }

    public var body: some View {
        VStack(spacing: 16) {
            Text(statusText).font(.headline).foregroundStyle(statusColor)
            Toggle(isOn: Binding(
                get: { connection.isConnected },
                set: { on in Task { on ? await connection.auto() : await connection.disconnect() } }
            )) { Text(connection.isConnected ? "Connected" : "Disconnected") }
            .toggleStyle(.switch)
            TrafficDashboardView(connection: connection)
        }
        .padding()
    }

    private var statusText: String {
        switch connection.state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
    private var statusColor: Color {
        switch connection.state {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .secondary
        }
    }
}
