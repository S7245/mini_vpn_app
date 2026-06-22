import NetworkExtension
import os

// THROWAWAY SPIKE — macOS NetworkExtension "tax" measurement.
//
// A NEPacketTunnelProvider subclass. This COMPILES but cannot be LOADED without
// the `com.apple.developer.networking.networkextension` entitlement + a matching
// provisioning profile (enable the NetworkExtension capability on the App ID in
// the Apple Developer portal — a paid-account step only the owner can do).
//
// The point of the scaffold is to make the A/C "tax" concrete by marking, line
// by line, what is UNAVOIDABLE NATIVE GLUE (per platform) vs what is SHAREABLE
// CORE LOGIC (option C: write once in Rust, call over FFI).

private let log = Logger(subsystem: "com.spike.netext", category: "provider")

final class PacketTunnelProvider: NEPacketTunnelProvider {

    // === UNAVOIDABLE NATIVE (Apple-specific NE glue) ===
    // Lifecycle entry point the OS calls. Signature, threading, completion
    // handler, and the NEPacketTunnelNetworkSettings dance are all Apple-only
    // and must be re-written natively on every Apple platform target.
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log.info("startTunnel")

        // The tunnel's virtual interface config — purely native NE types.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "203.0.113.9")
        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        settings.mtu = 1400
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1"])

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error { completionHandler(error); return }

            // === SHAREABLE CORE (option C: Rust over FFI) ===
            // Everything below the TUN boundary — the control handshake to the
            // backend ②, node selection, the actual data-plane (TLS+Yamux/QUIC
            // to Upstream), stats/state machine — is exactly the logic already
            // living in the Rust core. Under C this is `try await rustCore.start(config)`.
            // self.rustCore.start(...)  // ← one FFI call; no native re-impl.

            self?.startPacketLoop()
            completionHandler(nil)
        }
    }

    // === UNAVOIDABLE NATIVE ===
    // The packet read/write loop touches `self.packetFlow` (NEPacketTunnelFlow),
    // an Apple-only object. The BYTES are platform-neutral and would be handed
    // to/from the Rust core; the read/write plumbing is native per platform
    // (Apple: packetFlow; Android: VpnService ParcelFileDescriptor + a file loop).
    private func startPacketLoop() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            // C: self.rustCore.inbound(packets)  → core returns outbound packets
            // Here we just echo nothing and re-arm, to keep the scaffold compiling.
            _ = packets; _ = protocols
            self.startPacketLoop()
        }
    }

    // === UNAVOIDABLE NATIVE ===
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log.info("stopTunnel reason=\(reason.rawValue)")
        // C: rustCore.stop()
        completionHandler()
    }

    // === ① local-control SEAM (app ↔ extension IPC) ===
    // The GUI app talks to the running extension through this provider-message
    // channel. THIS is where the ① local-control schema (connect/disconnect/
    // selectNode/auto; state/stats/log) is actually transported on Apple. The
    // MESSAGE SEMANTICS are shareable/contract-defined; the transport (this
    // override + NETunnelProviderSession.sendProviderMessage) is native glue.
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // C: let reply = rustCore.handleControl(messageData)
        completionHandler?(messageData) // echo stub
    }
}
