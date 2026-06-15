import Foundation

@MainActor
public final class AccountViewModel: ObservableObject {
    @Published public private(set) var subscription: Subscription?
    @Published public private(set) var devices: [Device] = []
    @Published public private(set) var deviceLimit: Int = 0
    @Published public private(set) var errorMessage: String?

    private let backend: BackendService

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
}
