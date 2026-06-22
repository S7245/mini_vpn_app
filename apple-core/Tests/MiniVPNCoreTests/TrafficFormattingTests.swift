import XCTest
@testable import MiniVPNCore

final class TrafficFormattingTests: XCTestCase {
    func testRate() {
        XCTAssertEqual(TrafficDashboardView.rate(940_000), "940 Kbps")
        XCTAssertEqual(TrafficDashboardView.rate(128_000), "128 Kbps")
        XCTAssertEqual(TrafficDashboardView.rate(1_500_000), "1.5 Mbps")
    }

    func testBytes() {
        XCTAssertEqual(TrafficDashboardView.bytes(1_048_576), "1.0 MB")
        XCTAssertEqual(TrafficDashboardView.bytes(73_400_320), "70.0 MB")
    }
}
