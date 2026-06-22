import XCTest
@testable import MiniVPNCore

final class TokenPairTests: XCTestCase {
    func testDecodesContractMock() throws {
        let tp = try JSON.mock("token-pair", as: TokenPair.self)
        XCTAssertFalse(tp.accessToken.isEmpty)
        XCTAssertFalse(tp.refreshToken.isEmpty)
        XCTAssertEqual(tp.tokenType, "Bearer")
        XCTAssertEqual(tp.expiresIn, 3600)
    }
}
