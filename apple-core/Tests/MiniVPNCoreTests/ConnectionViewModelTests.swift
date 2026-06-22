import XCTest
@testable import MiniVPNCore

private final class ThrowingControlService: ControlService, @unchecked Sendable {
    func events() -> AsyncStream<ControlEvent> { AsyncStream { _ in } }
    func send(_ command: ControlCommand) async throws { throw ControlError.transport("boom") }
}

private final class ErrorEmittingControlService: ControlService, @unchecked Sendable {
    func events() -> AsyncStream<ControlEvent> {
        AsyncStream { cont in cont.yield(.error("stream failure")) }
    }
    func send(_ command: ControlCommand) async throws {}
}

@MainActor
final class ConnectionViewModelTests: XCTestCase {
    func testConnectUpdatesStateAndStats() async throws {
        let control = MockControlService(liveTicker: false)
        let vm = ConnectionViewModel(control: control)
        vm.start()
        await vm.connect(nodeId: "n1")

        // give the event loop a moment to drain the synchronous burst
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .connected)
        XCTAssertGreaterThan(vm.traffic.downBytes, 0)
        XCTAssertFalse(vm.logs.isEmpty)
    }

    func testSendFailureSurfacesAsError() async throws {
        let vm = ConnectionViewModel(control: ThrowingControlService())
        vm.start()
        await vm.connect(nodeId: "n1")
        XCTAssertEqual(vm.state, .error)
        XCTAssertTrue(vm.logs.contains { $0.level == .error })
    }

    func testStreamErrorEventSetsErrorState() async throws {
        let vm = ConnectionViewModel(control: ErrorEmittingControlService())
        vm.start()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.state, .error)
        XCTAssertTrue(vm.logs.contains { $0.level == .error })
    }

    func testDisconnect() async throws {
        let control = MockControlService(liveTicker: false)
        let vm = ConnectionViewModel(control: control)
        vm.start()
        await vm.connect(nodeId: "n1")
        try await Task.sleep(nanoseconds: 50_000_000)
        await vm.disconnect()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.state, .disconnected)
    }
}
