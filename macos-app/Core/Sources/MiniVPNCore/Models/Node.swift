import Foundation

public struct SharedNode: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let region: String
    public let city: String
    public let latencyMs: Int
    public let load: Double
    public let tier: String
}

public struct DedicatedNode: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let region: String
    public let city: String
    public let label: String
    public let staticIp: String
    public let expiresAt: String
    public let latencyMs: Int
    public let load: Double
}

public enum Node: Decodable, Equatable, Identifiable, Sendable {
    case shared(SharedNode)
    case dedicated(DedicatedNode)

    public var id: String {
        switch self {
        case .shared(let n): return n.id
        case .dedicated(let n): return n.id
        }
    }

    public var region: String {
        switch self {
        case .shared(let n): return n.region
        case .dedicated(let n): return n.region
        }
    }

    public var city: String {
        switch self {
        case .shared(let n): return n.city
        case .dedicated(let n): return n.city
        }
    }

    public var latencyMs: Int {
        switch self {
        case .shared(let n): return n.latencyMs
        case .dedicated(let n): return n.latencyMs
        }
    }

    private enum K: String, CodingKey { case kind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "shared": self = .shared(try SharedNode(from: decoder))
        case "dedicated": self = .dedicated(try DedicatedNode(from: decoder))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c,
                debugDescription: "unknown node kind \(other)")
        }
    }
}
