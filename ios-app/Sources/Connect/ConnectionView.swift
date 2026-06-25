import SwiftUI
import MiniVPNCore

/// 7.3 Connect. Big circular toggle (status-colored), status text, selected-node
/// card (auto for now; node selection wired in M4 via FR-09), live up/down
/// traffic. Drives the shared, tested ConnectionViewModel.
struct ConnectionView: View {
    @ObservedObject var connection: ConnectionViewModel

    var body: some View {
        VStack(spacing: 22) {
            Text("MiniVPN").font(.largeTitle).fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button {
                Task {
                    if connection.isConnected { await connection.disconnect() }
                    else { await connection.auto() }
                }
            } label: {
                ZStack {
                    Circle().stroke(statusColor, lineWidth: 4).frame(width: 150, height: 150)
                    if connection.state == .connecting {
                        ProgressView().scaleEffect(1.6).tint(statusColor)
                    } else {
                        Image(systemName: "power").font(.system(size: 54)).foregroundStyle(statusColor)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(connection.state == .connecting)
            .accessibilityLabel(connection.isConnected ? "Disconnect" : "Connect")

            Text(statusText).font(.title3).fontWeight(.medium).foregroundStyle(statusColor)

            nodeCard

            HStack(spacing: 12) {
                metric("Download", "arrow.down", bps: connection.traffic.downBps, bytes: connection.traffic.downBytes)
                metric("Upload", "arrow.up", bps: connection.traffic.upBps, bytes: connection.traffic.upBytes)
            }

            Spacer()
        }
        .padding(24)
        .task { connection.start() }
    }

    private var nodeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-select").fontWeight(.medium)
                Text("lowest latency").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(_ title: String, _ symbol: String, bps: Int, bytes: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(TrafficDashboardView.rate(bps)).font(.title2).fontWeight(.medium).monospacedDigit()
            Text("\(TrafficDashboardView.bytes(bytes)) total").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusText: String {
        switch connection.state {
        case .disconnected: return "未连接"
        case .connecting: return "连接中…"
        case .connected: return "已连接"
        case .error: return "连接出错"
        }
    }

    private var statusColor: Color {
        switch connection.state {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}
