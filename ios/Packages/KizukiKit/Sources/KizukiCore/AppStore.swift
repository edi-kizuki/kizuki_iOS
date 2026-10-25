import Foundation
import Observation

/// Screen-facing state. Reads through the repository protocols and refreshes after each mutation.
/// The same type serves the fixture prototype and (later) the live backend.
@MainActor @Observable
public final class AppStore {
    public private(set) var own: OwnProfile
    public private(set) var people: [Person] = []
    public private(set) var projects: [Project] = []
    public private(set) var requests: [CollabRequest] = []
    public private(set) var conversations: [Conversation] = []
    public private(set) var photos: [CollabPhoto] = []
    public private(set) var blocked: Set<UUID> = []
    public private(set) var recommendedProjects: [Recommendation<Project>] = []
    public private(set) var recommendedPeople: [Recommendation<Person>] = []
    public private(set) var isLoaded = false
    public private(set) var lastError: String?
    @ObservationIgnored private let deps: Dependencies

    public init(dependencies: Dependencies) {
        self.deps = dependencies
        self.own = OwnProfile(person: Person(id: UUID(), name: "", handle: "", realm: .film, roles: [], city: "", bio: ""))
    }

    public var me: Person { own.person }

    public func load() async {
        do {
            async let own = deps.own.own()
            async let people = deps.directory.people()
            async let photos = deps.directory.collabPhotos()
            async let rp = deps.directory.recommendedProjects()
            async let rpe = deps.directory.recommendedPeople()
            async let projects = deps.projects.projects()
            async let requests = deps.requests.requests()
            async let conversations = deps.conversations.conversations()
            async let blocked = deps.safety.blockedPeople()
            (self.own, self.people, self.photos) = try await (own, people, photos)
            (recommendedProjects, recommendedPeople) = try await (rp, rpe)
            (self.projects, self.requests, self.conversations, self.blocked) = try await (projects, requests, conversations, blocked)
            isLoaded = true
        } catch { lastError = "Couldn’t load. Try again." }
    }

    // MARK: Lookups (blocked people never appear)

    public func person(_ id: UUID) -> Person? { id == me.id ? me : people.first { $0.id == id } }
    public func project(_ id: UUID) -> Project? { projects.first { $0.id == id } }
    public func request(_ id: UUID) -> CollabRequest? { requests.first { $0.id == id } }
    public func isBlocked(_ id: UUID) -> Bool { blocked.contains(id) }
    public func photoAuthor(_ photo: CollabPhoto) -> Person? { person(photo.authorID) }

    public var visiblePhotos: [CollabPhoto] { photos.filter { !blocked.contains($0.authorID) } }
    public var visibleProjectRecommendations: [Recommendation<Project>] { recommendedProjects.filter { !blocked.contains($0.item.ownerID) } }
    public var visiblePeopleRecommendations: [Recommendation<Person>] { recommendedPeople.filter { !blocked.contains($0.item.id) } }
    public var blockedPeople: [Person] { people.filter { blocked.contains($0.id) } }

    /// Crew = people with an accepted request. Chat is reachable only for these people.
    public var crew: [Person] {
        var seen = Set<UUID>()
        return requests.filter { $0.state == .accepted && !blocked.contains($0.personID) }
            .compactMap { r in seen.insert(r.personID).inserted ? person(r.personID) : nil }
    }
    public func isInCrew(_ id: UUID) -> Bool { crew.contains { $0.id == id } }
    public var chatList: [Conversation] { conversations.filter { isInCrew($0.personID) } }
    public func conversation(with id: UUID) -> Conversation? { isInCrew(id) ? conversations.first { $0.personID == id } : nil }
    public func requests(_ direction: RequestDirection) -> [CollabRequest] {
        requests.filter { $0.direction == direction && !blocked.contains($0.personID) }
    }
    /// The user's own outgoing pending request to this person (for this project, or a Wish to Collab when nil).
    public func pendingRequest(for personID: UUID, project: UUID?) -> CollabRequest? {
        requests.first { $0.personID == personID && $0.projectID == project && $0.direction == .outgoing && $0.state == .pending }
    }
    /// A pending request this person sent to me (any kind). Lets their profile say "Review their request".
    public func incomingPending(from personID: UUID) -> CollabRequest? {
        requests.first { $0.personID == personID && $0.direction == .incoming && $0.state == .pending && !blocked.contains(personID) }
    }

    public func projects(_ status: [ProjectStatus], mine: Bool = true) -> [Project] {
        projects.filter { p in
            status.contains(p.status) && (p.ownerID == me.id || p.memberIDs.contains(me.id))
        }
    }
    public func isOwner(_ project: Project) -> Bool { project.ownerID == me.id }

    /// "Get discovered" checklist (decision 57): the profile fields that make the right people find you.
    public struct DiscoveryStep: Identifiable, Sendable, Hashable {
        public enum Kind: Sendable, Hashable { case bio, roles, favourites, link, collab }
        public let kind: Kind
        public let title: String
        public let done: Bool
        public var id: Kind { kind }
    }
    public var discoverySteps: [DiscoveryStep] {
        [DiscoveryStep(kind: .bio, title: "Write a short bio", done: me.bio.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10),
         DiscoveryStep(kind: .roles, title: "Pick your roles", done: !me.roles.isEmpty),
         DiscoveryStep(kind: .favourites, title: "Add favourite films or music", done: !own.favourites.isEmpty),
         DiscoveryStep(kind: .link, title: "Link your work", done: !me.links.isEmpty),
         DiscoveryStep(kind: .collab, title: "Post your first collab", done: photos.contains { $0.authorID == me.id })]
    }
    public var discoveryDoneCount: Int { discoverySteps.filter(\.done).count }

    // MARK: Mutations

    public func updateOwn(_ change: (inout OwnProfile) -> Void) {
        change(&own)
        let snapshot = own
        Task { try? await deps.own.save(snapshot); await refreshDirectory() }
    }
    public func sendRequest(_ request: NewRequest) async {
        do { try await deps.requests.send(request); requests = try await deps.requests.requests() }
        catch { lastError = "Couldn’t send. Try again." }
    }
    /// Returns the person who joined the Crew when accepted.
    @discardableResult
    public func respond(to requestID: UUID, with response: RequestResponse) async -> UUID? {
        guard let request = request(requestID), request.state == .pending else { return nil }
        do {
            try await deps.requests.respond(to: requestID, with: response)
            requests = try await deps.requests.requests()
            conversations = try await deps.conversations.conversations()
            return response == .accept ? request.personID : nil
        } catch { lastError = "Couldn’t update the request."; return nil }
    }
    /// Removes the person from the Crew and closes the chat. They are not blocked and can send a new request later.
    public func removeFromCrew(_ personID: UUID) async {
        guard isInCrew(personID) else { return }
        do {
            try await deps.requests.removeFromCrew(personID)
            requests = try await deps.requests.requests()
            conversations = try await deps.conversations.conversations()
        } catch { lastError = "Couldn’t remove from Crew. Try again." }
    }
    public func sendMessage(_ text: String, to personID: UUID) async {
        guard isInCrew(personID), !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        try? await deps.conversations.send(text, to: personID)
        conversations = (try? await deps.conversations.conversations()) ?? conversations
    }
    public func block(_ personID: UUID) async {
        try? await deps.safety.block(personID)
        await refreshAfterSafety()
    }
    public func unblock(_ personID: UUID) async {
        try? await deps.safety.unblock(personID)
        await refreshAfterSafety()
    }
    public func report(_ personID: UUID, reason: ReportReason, context: String) async {
        try? await deps.safety.report(personID: personID, reason: reason, context: context)
    }
    public func saveProject(_ project: Project) async {
        try? await deps.projects.save(project)
        projects = (try? await deps.projects.projects()) ?? projects
        recommendedProjects = (try? await deps.directory.recommendedProjects()) ?? recommendedProjects
    }
    public func postCollab(caption: String, tags: [String]) async {
        try? await deps.directory.postCollab(caption: caption, tags: tags)
        photos = (try? await deps.directory.collabPhotos()) ?? photos
    }

    private func refreshDirectory() async {
        recommendedProjects = (try? await deps.directory.recommendedProjects()) ?? recommendedProjects
        recommendedPeople = (try? await deps.directory.recommendedPeople()) ?? recommendedPeople
    }
    private func refreshAfterSafety() async {
        blocked = (try? await deps.safety.blockedPeople()) ?? blocked
        requests = (try? await deps.requests.requests()) ?? requests
        conversations = (try? await deps.conversations.conversations()) ?? conversations
    }
}
