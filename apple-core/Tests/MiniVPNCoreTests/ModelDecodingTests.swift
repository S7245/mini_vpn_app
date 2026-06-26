import XCTest
@testable import MiniVPNCore

final class ModelDecodingTests: XCTestCase {
    func testSubscription() throws {
        let s = try JSON.mock("subscription", as: Subscription.self)
        XCTAssertEqual(s.plan, "monthly")
        XCTAssertEqual(s.status, "active")
        XCTAssertEqual(s.deviceLimit, 3)
        XCTAssertNotNil(s.expiresAt)
    }

    func testDeviceList() throws {
        let dl = try JSON.mock("device-list", as: DeviceListDTO.self)
        XCTAssertEqual(dl.deviceLimit, 3)
        XCTAssertEqual(dl.devices.first?.platform, "macos")
    }

    func testNodeListMixedKinds() throws {
        let nl = try JSON.mock("node-list", as: NodeListDTO.self)
        XCTAssertEqual(nl.nodes.count, 3)
        // contract node-list.json has TWO shared (LA, Tokyo) + ONE dedicated (San Jose)
        var sawShared = false, sawDedicated = false
        for n in nl.nodes {
            switch n {
            case .shared(let s): sawShared = true; XCTAssertFalse(s.tier.isEmpty)
            case .dedicated(let d): sawDedicated = true; XCTAssertFalse(d.staticIp.isEmpty)
            }
        }
        XCTAssertTrue(sawShared && sawDedicated)
    }

    func testSelectBest() throws {
        let r = try JSON.mock("select-best", as: SelectBestResponse.self)
        XCTAssertFalse(r.nodeId.isEmpty)
        XCTAssertFalse(r.reason.isEmpty)
    }
}
