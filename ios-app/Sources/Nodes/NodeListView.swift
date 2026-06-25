import SwiftUI
import MiniVPNCore

/// 7.4 Nodes. List of shared/dedicated nodes; tap to select (single, mutually
/// exclusive), auto-select best; expired dedicated greyed + non-selectable
/// (Q-01). Selection flows to Connect via the shared NodeListViewModel (FR-09).
struct NodeListView: View {
    @ObservedObject var model: NodeListViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await model.selectBest() }
                    } label: {
                        Label("Auto-select best", systemImage: "bolt.fill")
                    }
                }
                Section {
                    ForEach(model.nodes) { node in
                        row(node)
                    }
                }
            }
            .navigationTitle("Nodes")
            .task { await model.load() }
            .refreshable { await model.load() }
            .overlay {
                if model.nodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "globe").font(.largeTitle).foregroundStyle(.secondary)
                        Text(model.errorMessage == nil ? "暂无可用节点" : "加载失败，下拉重试")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ node: Node) -> some View {
        let expired = isExpired(node)
        Button {
            if !expired { model.selectedNodeId = node.id }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(node.region) · \(node.city)").fontWeight(.medium)
                        if case .dedicated = node {
                            Text("dedicated").font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.tint))
                                .foregroundStyle(.tint)
                        }
                        if expired {
                            Text("已过期").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text(subtitle(node)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(node.latencyMs) ms").font(.subheadline).monospacedDigit()
                    if case .shared(let s) = node {
                        Text("load \(Int((s.load * 100).rounded()))%")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Image(systemName: model.selectedNodeId == node.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.selectedNodeId == node.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .contentShape(Rectangle())
            .opacity(expired ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(expired)
    }

    private func subtitle(_ node: Node) -> String {
        switch node {
        case .shared(let s): return "Shared · \(s.tier)"
        case .dedicated(let d): return "\(d.staticIp) · \(d.label)"
        }
    }

    private func isExpired(_ node: Node) -> Bool {
        guard case .dedicated(let d) = node else { return false }
        guard let date = ISO8601DateFormatter().date(from: d.expiresAt) else { return false }
        return date < Date()
    }
}
