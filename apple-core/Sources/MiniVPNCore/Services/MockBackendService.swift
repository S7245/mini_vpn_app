import Foundation

struct DeviceListDTO: Decodable { let devices: [Device]; let deviceLimit: Int }
struct NodeListDTO: Decodable { let nodes: [Node] }

/// Reads the contract mock fixtures bundled in Resources/Mocks.
public struct MockBackendService: BackendService {
    public init() {}

    public func register(email: String, password: String) async throws -> TokenPair {
        try JSON.mock("token-pair", as: TokenPair.self)
    }
    public func login(email: String, password: String) async throws -> TokenPair {
        try JSON.mock("token-pair", as: TokenPair.self)
    }
    public func refresh(refreshToken: String) async throws -> TokenPair {
        try JSON.mock("token-pair", as: TokenPair.self)
    }
    public func logout() async throws {}
    public func changePassword(old: String, new: String) async throws {}

    public func getSubscription() async throws -> Subscription {
        try JSON.mock("subscription", as: Subscription.self)
    }
    public func listDevices() async throws -> (devices: [Device], deviceLimit: Int) {
        let dto = try JSON.mock("device-list", as: DeviceListDTO.self)
        return (dto.devices, dto.deviceLimit)
    }
    public func registerDevice(name: String, platform: String) async throws -> Device {
        try JSON.mock("device", as: Device.self)
    }
    public func revokeDevice(id: String) async throws {}

    public func listNodes() async throws -> [Node] {
        try JSON.mock("node-list", as: NodeListDTO.self).nodes
    }
    public func selectBest() async throws -> SelectBestResponse {
        try JSON.mock("select-best", as: SelectBestResponse.self)
    }

    public func purchaseSubscription() async throws { throw BackendError.notImplemented }
    public func purchaseDedicatedIp() async throws { throw BackendError.notImplemented }
}
