import SwiftUI

public struct NodeListView: View {
    @ObservedObject var model: NodeListViewModel
    public init(model: NodeListViewModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Nodes").font(.headline)
                Spacer()
                Button("Auto-select best") { Task { await model.selectBest() } }
            }
            List(model.nodes, selection: $model.selectedNodeId) { node in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(node.region) · \(node.city)")
                        Text(kindLabel(node)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(node.latencyMs) ms").monospacedDigit().foregroundStyle(.secondary)
                }
                .tag(node.id)
            }
        }
        .padding()
        .task { await model.load() }
    }

    private func kindLabel(_ node: Node) -> String {
        switch node {
        case .shared(let s): return "Shared · \(s.tier)"
        case .dedicated(let d): return "Dedicated · \(d.staticIp)"
        }
    }
}
