import Foundation

public enum ConnectionState: String, Equatable, Sendable {
    case disconnected, connecting, connected, error
}

public enum ControlCommand: Equatable, Sendable {
    case connect(nodeId: String)
    case disconnect
    case selectNode(nodeId: String)
    case auto
}

public struct TrafficStats: Equatable, Sendable {
    public let upBps: Int
    public let downBps: Int
    public let upBytes: Int
    public let downBytes: Int
}

public enum LogLevel: String, Equatable, Sendable { case debug, info, warn, error }

public struct LogLine: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public let level: LogLevel
    public let message: String
    public let ts: Date
}

public enum ControlEvent: Sendable, Equatable {
    case state(ConnectionState)
    case stats(TrafficStats)
    case log(LogLine)
    case error(String)   // stream-level transport error detail (real impl)
}

/// Errors a command send can fail with. The mock never throws these, but the
/// real transport (unix socket / XPC / FFI) will — so the boundary already
/// carries them and the ViewModel already handles them. This keeps mock→real
/// a one-line swap with no call-site changes.
public enum ControlError: Error, Equatable, Sendable {
    case transport(String)
    case notConnected
}

/// ① GUI ↔ local core. The real impl binds a transport (unix socket / XPC /
/// FFI) later; the mock drives a deterministic state machine.
///
/// `send` is `async throws` (real transports fail) and the event stream carries
/// a `.error` case — both designed in NOW so swapping the mock for a real
/// transport does not change the protocol or any call site.
public protocol ControlService: Sendable {
    func send(_ command: ControlCommand) async throws
    func events() -> AsyncStream<ControlEvent>
}
