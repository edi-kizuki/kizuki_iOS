import Foundation

/// Minimal own-profile projection. No private settings, emails, or auth tokens.
public struct Profile: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let handle: String?
    public let displayHandle: String?
    public let avatarPath: String?

    public init(id: UUID, handle: String? = nil, displayHandle: String? = nil, avatarPath: String? = nil) {
        self.id = id
        self.handle = handle
        self.displayHandle = displayHandle
        self.avatarPath = avatarPath
    }

    enum CodingKeys: String, CodingKey {
        case id, handle
        case displayHandle = "display_handle"
        case avatarPath = "avatar_path"
    }
}

public protocol ProfileRepository: Sendable {
    /// Returns nil only for a successful query containing no visible own row.
    func ownProfile(for userID: UUID) async throws -> Profile?
}

public enum SessionEvent: Sendable, Equatable {
    case signedOut
    case signedIn(userID: UUID)
    case unavailable
}

public protocol SessionRepository: Sendable {
    func events() async -> AsyncStream<SessionEvent>
    func signOut() async throws
}
