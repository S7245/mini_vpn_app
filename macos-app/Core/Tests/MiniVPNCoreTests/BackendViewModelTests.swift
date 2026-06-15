import XCTest
@testable import MiniVPNCore

@MainActor
final class BackendViewModelTests: XCTestCase {
    func testNodeListLoads() async throws {
        let vm = NodeListViewModel(backend: MockBackendService())
        await vm.load()
        XCTAssertEqual(vm.nodes.count, 3)
        XCTAssertNil(vm.errorMessage)
    }

    func testSelectBestSetsSelection() async throws {
        let vm = NodeListViewModel(backend: MockBackendService())
        await vm.load()
        await vm.selectBest()
        XCTAssertNotNil(vm.selectedNodeId)
    }

    func testAccountLoadsSubscriptionAndDevices() async throws {
        let vm = AccountViewModel(backend: MockBackendService())
        await vm.load()
        XCTAssertEqual(vm.subscription?.deviceLimit, 3)
        XCTAssertEqual(vm.deviceLimit, 3)
        XCTAssertEqual(vm.devices.first?.platform, "macos")
    }
}
