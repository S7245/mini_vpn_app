import XCTest
@testable import MiniVPNCore

final class MockControlServiceTests: XCTestCase {
    func testConnectEmitsConnectingThenConnected() async throws {
        let svc = MockControlService(liveTicker: false)
        var states: [ConnectionState] = []
        let stream = svc.events()
        try await svc.send(.connect(nodeId: "n1"))
        var collected = 0
        for await event in stream {
            if case .state(let s) = event { states.append(s); collected += 1 }
            if collected >= 2 { break }
        }
        XCTAssertEqual(states, [.connecting, .connected])
    }

    func testConnectEmitsAtLeastOneStatsAndLog() async throws {
        let svc = MockControlService(liveTicker: false)
        let stream = svc.events()
        try await svc.send(.connect(nodeId: "n1"))
        var sawStats = false, sawLog = false
        for await event in stream {
            switch event {
            case .stats(let st): if st.downBps >= 0 { sawStats = true }
            case .log: sawLog = true
            default: break
            }
            if sawStats && sawLog { break }
        }
        XCTAssertTrue(sawStats && sawLog)
    }

    func testDisconnectEmitsDisconnected() async throws {
        let svc = MockControlService(liveTicker: false)
        let stream = svc.events()
        try await svc.send(.disconnect)
        for await event in stream {
            if case .state(.disconnected) = event { return }
        }
        XCTFail("never saw disconnected")
    }
}
