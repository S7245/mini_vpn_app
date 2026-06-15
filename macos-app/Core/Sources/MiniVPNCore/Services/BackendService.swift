import Foundation

public enum BackendError: Error, Equatable {
    case notImplemented
    case unauthorized
    case deviceLimitExceeded
    case transport(String)
}

/// ② App ↔ cloud control plane. Mock and real implementations conform to this.
public protocol BackendService: Sendable {
    func register(email: String, password: String) async throws -> TokenPair
    func login(email: String, password: String) async throws -> TokenPair
    func refresh(refreshToken: String) async throws -> TokenPair
    func logout() async throws
    func changePassword(old: String, new: String) async throws

    func getSubscription() async throws -> Subscription
    func listDevices() async throws -> (devices: [Device], deviceLimit: Int)
    func registerDevice(name: String, platform: String) async throws -> Device
    func revokeDevice(id: String) async throws

    func listNodes() async throws -> [Node]
    func selectBest() async throws -> SelectBestResponse

    func purchaseSubscription() async throws
    func purchaseDedicatedIp() async throws
}
