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

    func testTwoSubscribersBothReceiveConnecting() async throws {
        let svc = MockControlService(liveTicker: false)
        let s1 = svc.events()
        let s2 = svc.events()
        try await svc.send(.connect(nodeId: "n1"))

        func firstStateOrTimeout(_ stream: AsyncStream<ControlEvent>) async -> ConnectionState? {
            await withTaskGroup(of: ConnectionState?.self) { group in
                group.addTask {
                    for await e in stream { if case .state(let s) = e { return s } }
                    return nil
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    return nil
                }
                let result = await group.next() ?? nil
                group.cancelAll()
                return result
            }
        }

        async let a = firstStateOrTimeout(s1)
        async let b = firstStateOrTimeout(s2)
        let (ra, rb) = await (a, b)
        XCTAssertEqual(ra, .connecting)
        XCTAssertEqual(rb, .connecting)
    }
}
