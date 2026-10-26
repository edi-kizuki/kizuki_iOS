import Foundation

// Repository protocols the screens read through. `FixtureBackend` (KizukiTestSupport) implements them for the
// prototype; a Supabase-backed implementation arrives later behind the same protocols.

public protocol OwnProfileRepository: Sendable {
    func own() async throws -> OwnProfile
    func save(_ profile: OwnProfile) async throws
}
public protocol DirectoryRepository: Sendable {
    func people() async throws -> [Person]
    func collabPhotos() async throws -> [CollabPhoto]
    func recommendedProjects() async throws -> [Recommendation<Project>]
    func recommendedPeople() async throws -> [Recommendation<Person>]
    func postCollab(caption: String, tags: [String]) async throws
}
public protocol ProjectRepository: Sendable {
    func projects() async throws -> [Project]
    func save(_ project: Project) async throws
}
public protocol RequestRepository: Sendable {
    func requests() async throws -> [CollabRequest]
    func send(_ request: NewRequest) async throws
    /// Accepting also creates the conversation (server side in the live app).
    func respond(to requestID: UUID, with response: RequestResponse) async throws
    /// Ends the connection: the person leaves the Crew and the chat closes. Not a block (decision 54).
    func removeFromCrew(_ personID: UUID) async throws
}
public protocol ConversationRepository: Sendable {
    func conversations() async throws -> [Conversation]
    func send(_ text: String, to personID: UUID) async throws
}
public protocol SafetyRepository: Sendable {
    func blockedPeople() async throws -> Set<UUID>
    func block(_ personID: UUID) async throws
    func unblock(_ personID: UUID) async throws
    func report(personID: UUID, reason: ReportReason, context: String) async throws
}

public struct Dependencies: Sendable {
    public let sessions: any SessionRepository
    public let profiles: any ProfileRepository
    public let own: any OwnProfileRepository
    public let directory: any DirectoryRepository
    public let projects: any ProjectRepository
    public let requests: any RequestRepository
    public let conversations: any ConversationRepository
    public let safety: any SafetyRepository
    public init(sessions: any SessionRepository, profiles: any ProfileRepository, own: any OwnProfileRepository, directory: any DirectoryRepository, projects: any ProjectRepository,
                requests: any RequestRepository, conversations: any ConversationRepository, safety: any SafetyRepository) {
        self.sessions = sessions; self.profiles = profiles
        self.own = own; self.directory = directory; self.projects = projects
        self.requests = requests; self.conversations = conversations; self.safety = safety
    }
}
