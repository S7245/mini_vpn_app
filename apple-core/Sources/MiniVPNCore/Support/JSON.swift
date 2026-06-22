import Foundation

public enum JSON {
    /// Shared decoder: contract JSON is snake_case; Swift models are camelCase.
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Loads a bundled mock fixture by base name (e.g. "node-list").
    public static func mock<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Mocks") else {
            throw NSError(domain: "MiniVPNCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "missing mock \(name)"])
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
