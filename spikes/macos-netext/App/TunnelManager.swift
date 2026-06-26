import NetworkExtension
import Foundation

// App-side control of the packet-tunnel extension. The NETunnelProviderManager
// API is Apple-only NATIVE GLUE; the *intent* it carries (connect/disconnect/
// selectNode/auto; observe state/stats) is the shareable ① local-control
// contract. On Android the equivalent is VpnService + an Intent/Binder; the
// semantics are identical, the API is not.
final class TunnelManager {
    private var manager: NETunnelProviderManager?

    // === UNAVOIDABLE NATIVE ===
    // Provision the system's VPN configuration that points at our extension.
    func install() async throws {
        let mgrs = try await NETunnelProviderManager.loadAllFromPreferences()
        let mgr = mgrs.first ?? NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.spike.netext.PacketTunnel"
        proto.serverAddress = "mini-vpn" // shown in Settings; real value from backend ②
        // providerConfiguration is a free-form dict — the natural place to pass
        // the shareable config (selected node id, token) down to the extension.
        proto.providerConfiguration = ["nodeId": "auto"]
        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "MiniVPN (spike)"
        mgr.isEnabled = true
        try await mgr.saveToPreferences()
        self.manager = mgr
    }

    // === ① local-control: connect / disconnect (native transport) ===
    func connect() throws {
        try manager?.connection.startVPNTunnel()
    }
    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    // === ① local-control: command + state/stats over the message channel ===
    func send(_ command: Data) throws {
        guard let session = manager?.connection as? NETunnelProviderSession else { return }
        try session.sendProviderMessage(command) { _ in }
    }

    // === ① local-control: state stream (native KVO/notification) ===
    // The shareable part is the ConnectionState enum; the delivery is native.
    var state: NEVPNStatus { manager?.connection.status ?? .invalid }
}
