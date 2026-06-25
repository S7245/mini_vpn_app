import Foundation

@MainActor
public final class AccountViewModel: ObservableObject {
    @Published public private(set) var subscription: Subscription?
    @Published public private(set) var devices: [Device] = []
    @Published public private(set) var deviceLimit: Int = 0
    @Published public private(set) var errorMessage: String?

    private let backend: BackendService

    /// The device this app runs on. It is NOT revocable (Q-02: no self-revoke).
    /// Set by the app from its own registered device id; nil in mock until a
    /// real backend identifies the current device.
    public var currentDeviceId: String?

    public init(backend: BackendService) { self.backend = backend }

    public func load() async {
        do {
            subscription = try await backend.getSubscription()
            let (d, limit) = try await backend.listDevices()
            devices = d
            deviceLimit = limit
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }

    /// Whether a given device may be unbound (the current device may not — Q-02).
    public func canRevoke(_ id: String) -> Bool { id != currentDeviceId }

    /// FR-12: unbind a device. Removes it locally on success; the current device
    /// is never revoked.
    public func revoke(id: String) async {
        guard canRevoke(id) else { return }
        do {
            try await backend.revokeDevice(id: id)
            devices.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }
}
