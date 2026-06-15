import SwiftUI

public struct TrafficDashboardView: View {
    @ObservedObject var connection: ConnectionViewModel

    public init(connection: ConnectionViewModel) { self.connection = connection }

    public var body: some View {
        HStack(spacing: 32) {
            metric(title: "↓ Down", bps: connection.downBps, bytes: connection.downBytes)
            metric(title: "↑ Up", bps: connection.upBps, bytes: connection.upBytes)
        }
        .padding()
    }

    private func metric(title: String, bps: Int, bytes: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Self.rate(bps)).font(.title2).monospacedDigit()
            Text(Self.bytes(bytes)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    static func rate(_ bps: Int) -> String {
        let kbps = Double(bps) / 1000.0
        return kbps >= 1000 ? String(format: "%.1f Mbps", kbps / 1000) : String(format: "%.0f Kbps", kbps)
    }
    static func bytes(_ b: Int) -> String {
        let mb = Double(b) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }
}
