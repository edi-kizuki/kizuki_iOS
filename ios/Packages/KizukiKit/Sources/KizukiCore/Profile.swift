import Foundation

public enum AccountStatus: String, Codable, Sendable {
    case active, deleting, deleted, suspended
}

/// Minimal own-profile projection. No private settings, emails, or auth tokens.
public struct Profile: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let handle: String?
    public let displayHandle: String?
    public let avatarPath: String?

    public let onboardingCompletedAt: Date?
    public let eligibleAt: Date?
    public let accountStatus: AccountStatus
    public let onboardingStep: Int

    public init(id: UUID, handle: String? = nil, displayHandle: String? = nil, avatarPath: String? = nil,
                onboardingCompletedAt: Date? = nil, eligibleAt: Date? = nil,
                accountStatus: AccountStatus = .active, onboardingStep: Int = 0) {
        self.id = id
        self.handle = handle
        self.displayHandle = displayHandle
        self.avatarPath = avatarPath
        self.onboardingCompletedAt = onboardingCompletedAt
        self.eligibleAt = eligibleAt
        self.accountStatus = accountStatus
        self.onboardingStep = onboardingStep
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        handle = try values.decodeIfPresent(String.self, forKey: .handle)
        displayHandle = try values.decodeIfPresent(String.self, forKey: .displayHandle)
        avatarPath = try values.decodeIfPresent(String.self, forKey: .avatarPath)
        onboardingCompletedAt = try values.decodeIfPresent(Date.self, forKey: .onboardingCompletedAt)
        eligibleAt = try values.decodeIfPresent(Date.self, forKey: .eligibleAt)
        accountStatus = try values.decodeIfPresent(AccountStatus.self, forKey: .accountStatus) ?? .active
        onboardingStep = try values.decodeIfPresent(Int.self, forKey: .onboardingStep) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id, handle
        case displayHandle = "display_handle"
        case avatarPath = "avatar_path"
        case onboardingCompletedAt = "onboarding_completed_at"
        case eligibleAt = "eligible_at"
        case accountStatus = "account_status"
        case onboardingStep = "onboarding_step"
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
    case verificationRequired(userID: UUID)
    case passwordRecovery(userID: UUID)
    case userUpdated(userID: UUID, emailVerified: Bool)
}

public protocol SessionRepository: Sendable {
    func events() async -> AsyncStream<SessionEvent>
    func signOut() async throws
}
