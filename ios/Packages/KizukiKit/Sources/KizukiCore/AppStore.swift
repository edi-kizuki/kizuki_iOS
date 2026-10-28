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
        public enum Kind: Sendable, Hashable { case name, bio, city, roles }
        public let kind: Kind
        public let title: String
        public let done: Bool
        public var id: Kind { kind }
    }
    public var discoverySteps: [DiscoveryStep] {
        let bio = me.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let roles = me.roles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return [DiscoveryStep(kind: .name, title: "Add your display name", done: me.name.rangeOfCharacter(from: .letters) != nil),
                DiscoveryStep(kind: .bio, title: "Write a short bio (10+ characters)", done: bio.count >= 10 && bio.rangeOfCharacter(from: .letters) != nil),
                DiscoveryStep(kind: .city, title: "Add your city", done: me.city.rangeOfCharacter(from: .letters) != nil),
                DiscoveryStep(kind: .roles, title: "Pick your roles", done: RoleSelection.isValid(roles, realm: me.realm))]
            .filter { own.goal == .collaborate || $0.kind != .roles }
    }
    public var discoveryDoneCount: Int { discoverySteps.filter(\.done).count }
    public var isProfileComplete: Bool { discoverySteps.allSatisfy(\.done) }

    public enum FeedPrompt: Identifiable, Hashable, Sendable {
        case finishProject(UUID), reviewRequests(Int), completeProfile, startConversation(UUID)

        public var id: String {
            switch self {
            case .finishProject: "draft"
            case .reviewRequests: "requests"
            case .completeProfile: "profile"
            case .startConversation: "crew"
            }
        }
    }

    public var feedPrompts: [FeedPrompt] {
        guard isLoaded else { return [] }
        var prompts: [FeedPrompt] = []
        if own.goal == .collaborate {
            if let draft = projects([.draft]).first(where: isOwner) {
                prompts.append(.finishProject(draft.id))
            }
            let pending = requests(.incoming).filter { $0.state == .pending }.count
            if pending > 0 { prompts.append(.reviewRequests(pending)) }
        }
        if !isProfileComplete { prompts.append(.completeProfile) }
        if own.goal == .collaborate,
           let person = crew.first(where: { conversation(with: $0.id)?.messages.isEmpty ?? true }) {
            prompts.append(.startConversation(person.id))
        }
        return prompts
    }

    public func saveProfileBasics(name: String, bio: String, city: String, roles: [String], availability: Availability, compensation: Compensation, goal: Goal? = nil, links: [ProfileLink]? = nil, portrait: ProfilePhotoUpdate = .unchanged, cover: ProfilePhotoUpdate = .unchanged) async -> Bool {
        guard portrait.isValid, cover.isValid else { return false }
        var profile = own
        switch portrait {
        case .unchanged: break
        case .remove: profile.person.portraitData = nil; profile.person.portraitAsset = nil
        case .replace(let data): profile.person.portraitData = data; profile.person.portraitAsset = nil
        }
        switch cover {
        case .unchanged: break
        case .remove: profile.person.coverData = nil
        case .replace(let data): profile.person.coverData = data
        }
        if let links {
            guard Set(links.map(\.kind)).count == links.count else { return false }
            var validatedLinks: [ProfileLink] = []
            for link in links {
                if own.person.links.contains(where: { $0.kind == link.kind && $0.url == link.url }) {
                    validatedLinks.append(link)
                } else {
                    guard let url = link.kind.normalizedPortfolioURL(link.url) else { return false }
                    validatedLinks.append(ProfileLink(kind: link.kind, title: link.title, url: url, isEnabled: link.isEnabled))
                }
            }
            profile.person.links = validatedLinks
        }
        if let goal { profile.goal = goal }
        profile.person.collaborationEnabled = profile.goal == .collaborate
        profile.person.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.person.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.person.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.person.roles = roles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard RoleSelection.isValid(profile.person.roles, realm: profile.person.realm, allowEmpty: true) else { return false }
        profile.availability = availability
        profile.person.availability = availability
        profile.compensation = compensation
        do {
            try await deps.own.save(profile)
            own = profile
            await refreshDirectory()
            return true
        } catch {
            return false
        }
    }

    // MARK: Mutations

    public func completeOnboarding(_ draft: OwnProfile) async -> Bool {
        var profile = draft
        guard RoleSelection.isValid(profile.person.roles, realm: profile.person.realm, allowEmpty: profile.goal == .explore) else { return false }
        profile.person.collaborationEnabled = profile.goal == .collaborate
        profile.person.availability = profile.availability
        profile.onboardingCompleted = true
        do {
            try await deps.own.save(profile)
            own = profile
            await refreshDirectory()
            return true
        } catch { return false }
    }

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
