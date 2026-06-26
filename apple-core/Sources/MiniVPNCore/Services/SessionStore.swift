import Foundation

/// Persists the session token pair. Mock-first impl uses UserDefaults; the real
/// implementation will use the Keychain (same protocol, swap the impl).
public protocol SessionStore: Sendable {
    func save(_ tokens: TokenPair)
    func load() -> TokenPair?
    func clear()
}

public final class UserDefaultsSessionStore: SessionStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "minivpn.session.tokens"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(_ tokens: TokenPair) {
        if let data = try? JSONEncoder().encode(tokens) {
            defaults.set(data, forKey: key)
        }
    }

    public func load() -> TokenPair? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TokenPair.self, from: data)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
