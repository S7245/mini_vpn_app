import SwiftUI

public struct LogsView: View {
    @ObservedObject var connection: ConnectionViewModel
    public init(connection: ConnectionViewModel) { self.connection = connection }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("Logs").font(.headline)
            List(connection.logs) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text(line.level.rawValue.uppercased())
                        .font(.caption2).foregroundStyle(color(line.level))
                        .frame(width: 44, alignment: .leading)
                    Text(line.message).font(.system(.caption, design: .monospaced))
                }
            }
        }
        .padding()
    }

    private func color(_ l: LogLevel) -> Color {
        switch l {
        case .debug: return .secondary
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }
}
