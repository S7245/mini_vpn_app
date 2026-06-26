// The image snapshot renders via NSHostingView (AppKit) — macOS only. Guard the
// whole file so the shared package still compiles for iOS. iOS view snapshots,
// if wanted later, would use UIHostingView under `#if canImport(UIKit)`.
#if canImport(AppKit)
import XCTest
import SwiftUI
import SnapshotTesting
@testable import MiniVPNCore

@MainActor
final class SnapshotTests: XCTestCase {
    func testTrafficDashboardSnapshot() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SNAPSHOT"] == "1",
            "image snapshot is host-dependent; set SNAPSHOT=1 to run"
        )
        let control = MockControlService(liveTicker: false)
        let vm = ConnectionViewModel(control: control)
        let view = TrafficDashboardView(connection: vm).frame(width: 320, height: 120)
        assertSnapshot(of: NSHostingView(rootView: view), as: .image(size: CGSize(width: 320, height: 120)))
    }
}
#endif
