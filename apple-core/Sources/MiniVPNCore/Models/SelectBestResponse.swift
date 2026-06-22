import Foundation

public struct SelectBestResponse: Codable, Equatable, Sendable {
    public let nodeId: String
    public let reason: String
}
