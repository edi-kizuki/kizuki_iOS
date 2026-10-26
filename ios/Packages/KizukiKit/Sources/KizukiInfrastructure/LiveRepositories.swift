import Foundation
import KizukiCore

public enum LiveRepositoryError: Error, Equatable, LocalizedError {
    case notYetAvailable(String)
    public var errorDescription: String? { "This feature is not available yet." }
}

/// B02+ supplies schema and individual live implementations. Never substitute invented data.
private struct UnavailableRepositories: OwnProfileRepository, DirectoryRepository, ProjectRepository,
    RequestRepository, ConversationRepository, SafetyRepository {
    func own() async throws -> OwnProfile { throw LiveRepositoryError.notYetAvailable("ownProfile") }
    func save(_ profile: OwnProfile) async throws { throw LiveRepositoryError.notYetAvailable("saveProfile") }
    func people() async throws -> [Person] { throw LiveRepositoryError.notYetAvailable("people") }
    func collabPhotos() async throws -> [CollabPhoto] { throw LiveRepositoryError.notYetAvailable("collabPhotos") }
    func recommendedProjects() async throws -> [Recommendation<Project>] { throw LiveRepositoryError.notYetAvailable("recommendedProjects") }
    func recommendedPeople() async throws -> [Recommendation<Person>] { throw LiveRepositoryError.notYetAvailable("recommendedPeople") }
    func postCollab(caption: String, tags: [String]) async throws { throw LiveRepositoryError.notYetAvailable("postCollab") }
    func projects() async throws -> [Project] { throw LiveRepositoryError.notYetAvailable("projects") }
    func save(_ project: Project) async throws { throw LiveRepositoryError.notYetAvailable("saveProject") }
    func requests() async throws -> [CollabRequest] { throw LiveRepositoryError.notYetAvailable("requests") }
    func send(_ request: NewRequest) async throws { throw LiveRepositoryError.notYetAvailable("sendRequest") }
    func respond(to requestID: UUID, with response: RequestResponse) async throws { throw LiveRepositoryError.notYetAvailable("respondRequest") }
    func removeFromCrew(_ personID: UUID) async throws { throw LiveRepositoryError.notYetAvailable("removeFromCrew") }
    func conversations() async throws -> [Conversation] { throw LiveRepositoryError.notYetAvailable("conversations") }
    func send(_ text: String, to personID: UUID) async throws { throw LiveRepositoryError.notYetAvailable("sendMessage") }
    func blockedPeople() async throws -> Set<UUID> { throw LiveRepositoryError.notYetAvailable("blockedPeople") }
    func block(_ personID: UUID) async throws { throw LiveRepositoryError.notYetAvailable("block") }
    func unblock(_ personID: UUID) async throws { throw LiveRepositoryError.notYetAvailable("unblock") }
    func report(personID: UUID, reason: ReportReason, context: String) async throws { throw LiveRepositoryError.notYetAvailable("report") }
}

public extension Dependencies {
    static func live(configuration: AppConfiguration) -> Self {
        live(backend: SupabaseBackend(configuration: configuration))
    }

    /// A single SDK client supplies both session and own-profile reads.
    static func live(backend: SupabaseBackend) -> Self {
        live(sessions: backend, profiles: backend)
    }

    /// Allows session/profile stubs to exercise the same root with honest unavailable feature repositories.
    static func live(sessions: any SessionRepository, profiles: any ProfileRepository) -> Self {
        let pending = UnavailableRepositories()
        return Self(sessions: sessions, profiles: profiles, own: pending, directory: pending,
                    projects: pending, requests: pending, conversations: pending, safety: pending)
    }
}
