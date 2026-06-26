import SwiftUI
import MiniVPNCore

/// 7.5 Account. Subscription (read-only), device list with swipe-to-revoke
/// (current device excluded, Q-02), and log out.
struct AccountView: View {
    @ObservedObject var account: AccountViewModel
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Subscription") {
                    if let sub = account.subscription {
                        LabeledContent("Plan", value: sub.plan)
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(sub.status)
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(statusColor(sub.status).opacity(0.18), in: Capsule())
                                .foregroundStyle(statusColor(sub.status))
                        }
                        LabeledContent("Expires", value: formatted(sub.expiresAt))
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(account.devices) { device in
                        deviceRow(device)
                    }
                } header: {
                    HStack {
                        Text("Devices")
                        Spacer()
                        Text("\(account.devices.count) of \(account.deviceLimit)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await auth.logout() }
                    } label: {
                        Text("Log out").frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Account")
            .task { await account.load() }
            .refreshable { await account.load() }
        }
    }

    @ViewBuilder
    private func deviceRow(_ device: Device) -> some View {
        let isCurrent = device.id == account.currentDeviceId
        HStack(spacing: 10) {
            Image(systemName: device.platform == "ios" ? "iphone" : "laptopcomputer")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).fontWeight(.medium)
                Text(isCurrent ? "\(device.platform) · this device" : device.platform)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            if account.canRevoke(device.id) {
                Button(role: .destructive) {
                    Task { await account.revoke(id: device.id) }
                } label: { Label("解绑", systemImage: "trash") }
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        status == "active" ? .green : .secondary
    }

    private func formatted(_ iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
