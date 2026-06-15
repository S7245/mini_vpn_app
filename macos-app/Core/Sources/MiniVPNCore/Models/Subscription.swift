import Foundation

public struct Subscription: Codable, Equatable, Sendable {
    public let plan: String
    public let status: String
    public let expiresAt: String?
    public let deviceLimit: Int
}
