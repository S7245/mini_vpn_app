import Foundation
import Combine

@MainActor
public final class ConnectionViewModel: ObservableObject {
    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public private(set) var upBps: Int = 0
    @Published public private(set) var downBps: Int = 0
    @Published public private(set) var upBytes: Int = 0
    @Published public private(set) var downBytes: Int = 0
    @Published public private(set) var logs: [LogLine] = []

    private let control: ControlService
    private var pump: Task<Void, Never>?

    public init(control: ControlService) {
        self.control = control
    }

    /// Begin draining the control event stream into published state.
    public func start() {
        pump?.cancel()
        let stream = control.events()
        pump = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await self.apply(event)
            }
        }
    }

    private func apply(_ event: ControlEvent) {
        switch event {
        case .state(let s): state = s
        case .stats(let st):
            upBps = st.upBps; downBps = st.downBps
            upBytes = st.upBytes; downBytes = st.downBytes
        case .log(let line):
            append(line)
        case .error(let detail):
            state = .error
            append(LogLine(level: .error, message: detail, ts: Date()))
        }
    }

    private func append(_ line: LogLine) {
        logs.append(line)
        if logs.count > 500 { logs.removeFirst(logs.count - 500) }
    }

    /// Command helpers absorb a `send` failure into `.error` + a log so the call
    /// sites (views) stay non-throwing — this is what keeps the mock→real swap
    /// from rippling into the UI.
    public func connect(nodeId: String) async { await send(.connect(nodeId: nodeId)) }
    public func auto() async { await send(.auto) }
    public func disconnect() async { await send(.disconnect) }

    private func send(_ command: ControlCommand) async {
        do {
            try await control.send(command)
        } catch {
            state = .error
            append(LogLine(level: .error, message: "\(error)", ts: Date()))
        }
    }

    public var isConnected: Bool { state == .connected }
}
