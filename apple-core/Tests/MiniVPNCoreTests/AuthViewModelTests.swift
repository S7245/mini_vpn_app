import XCTest
@testable import MiniVPNCore

private func ephemeralStore() -> UserDefaultsSessionStore {
    let suite = "minivpn.test.\(UUID().uuidString)"
    return UserDefaultsSessionStore(defaults: UserDefaults(suiteName: suite)!)
}

private struct FailingBackend: BackendService {
    let error: BackendError
    func register(email: String, password: String) async throws -> TokenPair { throw error }
    func login(email: String, password: String) async throws -> TokenPair { throw error }
    func refresh(refreshToken: String) async throws -> TokenPair { throw error }
    func logout() async throws { throw error }
    func changePassword(old: String, new: String) async throws { throw error }
    func getSubscription() async throws -> Subscription { throw error }
    func listDevices() async throws -> (devices: [Device], deviceLimit: Int) { throw error }
    func registerDevice(name: String, platform: String) async throws -> Device { throw error }
    func revokeDevice(id: String) async throws { throw error }
    func listNodes() async throws -> [Node] { throw error }
    func selectBest() async throws -> SelectBestResponse { throw error }
    func purchaseSubscription() async throws { throw error }
    func purchaseDedicatedIp() async throws { throw error }
}

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testLoginSuccessAuthenticatesAndPersists() async {
        let store = ephemeralStore()
        let vm = AuthViewModel(backend: MockBackendService(), store: store)
        XCTAssertFalse(vm.isAuthenticated)
        await vm.login(email: "a@b.com", password: "password123")
        XCTAssertTrue(vm.isAuthenticated)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNotNil(store.load())
    }

    func testRegisterSuccessAuthenticates() async {
        let vm = AuthViewModel(backend: MockBackendService(), store: ephemeralStore())
        await vm.register(email: "a@b.com", password: "password123")
        XCTAssertTrue(vm.isAuthenticated)
    }

    func testLogoutClearsSessionAndStore() async {
        let store = ephemeralStore()
        let vm = AuthViewModel(backend: MockBackendService(), store: store)
        await vm.login(email: "a@b.com", password: "password123")
        await vm.logout()
        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNil(store.load())
    }

    func testRestoresSessionOnInitWhenTokenPersisted() {
        let store = ephemeralStore()
        store.save(TokenPair(accessToken: "a", refreshToken: "r", tokenType: "Bearer", expiresIn: 3600))
        let vm = AuthViewModel(backend: MockBackendService(), store: store)
        XCTAssertTrue(vm.isAuthenticated)
    }

    func testLoginFailureSurfacesMappedError() async {
        let vm = AuthViewModel(backend: FailingBackend(error: .unauthorized), store: ephemeralStore())
        await vm.login(email: "a@b.com", password: "wrong")
        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertEqual(vm.errorMessage, "邮箱或密码错误")
    }
}
