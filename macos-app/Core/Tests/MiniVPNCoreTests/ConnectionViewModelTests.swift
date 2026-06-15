import XCTest
@testable import MiniVPNCore

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
        XCTAssertGreaterThan(vm.downBytes, 0)
        XCTAssertFalse(vm.logs.isEmpty)
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
