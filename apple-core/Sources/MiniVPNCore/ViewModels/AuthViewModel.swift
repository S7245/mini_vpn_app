import Foundation

/// Auth + session gate. Restores a persisted session on init (Q-03: remember
/// login). login/register persist the returned tokens; logout clears them
/// (best-effort backend logout, but local session is cleared regardless).
@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public private(set) var isAuthenticated: Bool
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isLoading = false

    private let backend: BackendService
    private let store: SessionStore

    public init(backend: BackendService, store: SessionStore) {
        self.backend = backend
        self.store = store
        self.isAuthenticated = store.load() != nil
    }

    public func login(email: String, password: String) async {
        await authenticate { try await self.backend.login(email: email, password: password) }
    }

    public func register(email: String, password: String) async {
        await authenticate { try await self.backend.register(email: email, password: password) }
    }

    public func logout() async {
        try? await backend.logout()
        store.clear()
        isAuthenticated = false
    }

    private func authenticate(_ op: () async throws -> TokenPair) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let tokens = try await op()
            store.save(tokens)
            isAuthenticated = true
        } catch {
            errorMessage = Self.message(for: error)
            isAuthenticated = false
        }
    }

    private static func message(for error: Error) -> String {
        guard let be = error as? BackendError else { return "登录失败，请重试" }
        switch be {
        case .unauthorized: return "邮箱或密码错误"
        case .transport: return "网络异常，请重试"
        default: return "登录失败，请重试"
        }
    }
}
