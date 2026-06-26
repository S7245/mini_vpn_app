import XCTest
@testable import MiniVPNCore

final class MockBackendServiceTests: XCTestCase {
    func testListNodesReturnsContractNodes() async throws {
        let svc = MockBackendService()
        let nodes = try await svc.listNodes()
        XCTAssertEqual(nodes.count, 3)
    }

    func testSubscriptionAndDevices() async throws {
        let svc = MockBackendService()
        let sub = try await svc.getSubscription()
        XCTAssertEqual(sub.deviceLimit, 3)
        let (devices, limit) = try await svc.listDevices()
        XCTAssertEqual(limit, 3)
        XCTAssertEqual(devices.first?.platform, "macos")
    }

    func testLoginReturnsTokens() async throws {
        let svc = MockBackendService()
        let tp = try await svc.login(email: "a@b.com", password: "password123")
        XCTAssertEqual(tp.tokenType, "Bearer")
    }

    func testSelectBest() async throws {
        let svc = MockBackendService()
        let r = try await svc.selectBest()
        XCTAssertFalse(r.nodeId.isEmpty)
    }

    func testPurchaseThrowsNotImplemented() async {
        let svc = MockBackendService()
        do {
            try await svc.purchaseSubscription()
            XCTFail("expected notImplemented")
        } catch BackendError.notImplemented {
            // expected
        } catch {
            XCTFail("wrong error \(error)")
        }
    }
}
