import SwiftUI

public struct SettingsView: View {
    @ObservedObject var account: AccountViewModel
    public init(account: AccountViewModel) { self.account = account }

    public var body: some View {
        Form {
            Section("Subscription") {
                LabeledContent("Plan", value: account.subscription?.plan ?? "—")
                LabeledContent("Status", value: account.subscription?.status ?? "—")
                LabeledContent("Devices", value: "\(account.devices.count) / \(account.deviceLimit)")
            }
            Section("Devices") {
                ForEach(account.devices) { d in
                    LabeledContent(d.name, value: d.platform)
                }
            }
        }
        .padding()
        .task { await account.load() }
    }
}
