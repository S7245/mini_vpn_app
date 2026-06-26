import Foundation

public struct Device: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let platform: String
    public let lastSeenAt: String
    public let createdAt: String
}
