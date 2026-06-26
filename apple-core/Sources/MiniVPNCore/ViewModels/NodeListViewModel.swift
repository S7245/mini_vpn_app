import Foundation

@MainActor
public final class NodeListViewModel: ObservableObject {
    @Published public private(set) var nodes: [Node] = []
    @Published public var selectedNodeId: String?
    @Published public private(set) var errorMessage: String?

    private let backend: BackendService

    public init(backend: BackendService) { self.backend = backend }

    public func load() async {
        do {
            nodes = try await backend.listNodes()
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }

    public func selectBest() async {
        do {
            selectedNodeId = try await backend.selectBest().nodeId
        } catch {
            errorMessage = "\(error)"
        }
    }
}
