import Foundation

/// Only a flow marker and user ID are persisted. Live callers supply an environment-specific namespace.
/// No credentials or recovery codes are stored. Tests default to isolated memory.
@MainActor
public final class PasswordRecoveryState {
    private let defaults: UserDefaults?
    private let key: String
    private var memory: String?

    public init(defaults: UserDefaults? = nil, namespace: String = "memory") {
        self.defaults = defaults
        key = namespace + ".passwordRecovery"
    }

    private var pending: String? {
        get { defaults?.string(forKey: key) ?? memory }
        set { memory = newValue; defaults?.set(newValue, forKey: key) }
    }

    public func begin(for userID: UUID? = nil) { pending = userID?.uuidString ?? "awaiting-verified-identity" }

    public func isPending(for userID: UUID) -> Bool {
        if pending == "awaiting-verified-identity" { pending = userID.uuidString }
        return pending == userID.uuidString
    }

    public func finish(for userID: UUID) {
        if pending == userID.uuidString { pending = nil }
    }
}
