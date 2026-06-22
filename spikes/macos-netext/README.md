# spike: macos-netext (throwaway)

A **compile-only** `NEPacketTunnelProvider` scaffold to measure the macOS
network-extension "tax" for the §7.1 A/C decision. It is NOT a working VPN.

- `Extension/PacketTunnelProvider.swift` — the NE provider, annotated with what's
  unavoidable native glue vs shareable Rust core (option C) vs the ① local-control seam.
- `App/TunnelManager.swift` + `App/SpikeApp.swift` — app-side `NETunnelProviderManager`.
- `Extension/{Info.plist,Extension.entitlements}`, `App/App.entitlements` — the
  required NetworkExtension capability (the entitlement IS part of the tax).
- `TAX.md` — **the deliverable**: the A/C measuring stick and conclusion.

Build (compiles; cannot LOAD without the NetworkExtension entitlement + a
provisioning profile from the Apple Developer portal):
```bash
xcodegen generate
xcodebuild -project SpikeNetExt.xcodeproj -scheme SpikeNetExt \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
