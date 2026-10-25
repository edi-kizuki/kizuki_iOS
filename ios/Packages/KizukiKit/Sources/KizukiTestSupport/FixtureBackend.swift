#if DEBUG
import Foundation
import KizukiCore

/// In-memory implementation of every repository protocol. State lives for the process lifetime.
public actor FixtureBackend: OwnProfileRepository, DirectoryRepository, ProjectRepository, RequestRepository, ConversationRepository, SafetyRepository {
    private var ownProfile = FixtureData.ownProfile
    private var photoList = FixtureData.photos
    private var projectList = FixtureData.projects
    private var requestList = FixtureData.requests
    private var conversationList = FixtureData.conversations
    private var blockedSet: Set<UUID> = [FixtureData.personID(19)]

    public init() {}

    public nonisolated static func dependencies() -> Dependencies {
        let backend = FixtureBackend()
        return Dependencies(own: backend, directory: backend, projects: backend, requests: backend, conversations: backend, safety: backend)
    }

    // MARK: OwnProfileRepository
    public func own() -> OwnProfile { ownProfile }
    public func save(_ profile: OwnProfile) { ownProfile = profile }

    // MARK: DirectoryRepository
    public func people() -> [Person] { Array(FixtureData.people.dropFirst()) }
    public func collabPhotos() -> [CollabPhoto] { photoList }
    public func postCollab(caption: String, tags: [String]) {
        photoList.insert(CollabPhoto(authorID: FixtureData.meID, caption: caption, tags: tags, artSeed: photoList.count + 3), at: 0)
    }
    public func recommendedProjects() -> [Recommendation<Project>] {
        projectList.filter { $0.status == .published && $0.ownerID != FixtureData.meID && !$0.memberIDs.contains(FixtureData.meID) }.map { p in
            var reasons: [String] = []
            if p.city == ownProfile.person.city { reasons.append("In your city") }
            if p.realm == ownProfile.person.realm { reasons.append("Your discipline") }
            if p.rolesNeeded.contains(where: ownProfile.person.roles.contains) { reasons.append("Needs your role") }
            if ownProfile.useTasteForMatching, ownProfile.tasteCards.contains(p.artSeed % 6) { reasons.append("Shared taste") }
            if p.compensation == .paid, ownProfile.compensation != .passion { reasons.append("Paid work") }
            return Recommendation(item: p, reasons: reasons.isEmpty ? ["New in Berlin"] : reasons)
        }
    }
    public func recommendedPeople() -> [Recommendation<Person>] {
        FixtureData.people.dropFirst().map { person in
            var reasons: [String] = []
            if person.city == ownProfile.person.city { reasons.append("Nearby") }
            if person.realm == ownProfile.person.realm { reasons.append("Same realm") } else { reasons.append("Different realm") }
            if ownProfile.useFavouritesForMatching, person.favourites.contains(where: ownProfile.favourites.contains) { reasons.append("Shared favourites") }
            if person.name.count % 3 == 0 { reasons.insert("Shared taste", at: 0) }
            return Recommendation(item: person, reasons: reasons)
        }
    }

    // MARK: ProjectRepository
    public func projects() -> [Project] { projectList }
    public func save(_ project: Project) {
        if let i = projectList.firstIndex(where: { $0.id == project.id }) { projectList[i] = project } else { projectList.insert(project, at: 0) }
    }

    // MARK: RequestRepository
    public func requests() -> [CollabRequest] { requestList }
    public func send(_ request: NewRequest) {
        // Duplicate pending requests to the same target are ignored (concept 4.4).
        guard !requestList.contains(where: { $0.personID == request.personID && $0.projectID == request.projectID && $0.direction == .outgoing && $0.state == .pending }) else { return }
        requestList.append(CollabRequest(personID: request.personID, projectID: request.projectID, direction: .outgoing, state: .pending,
                                         role: request.role, timeCommitment: request.timeCommitment, note: request.note))
    }
    public func respond(to requestID: UUID, with response: RequestResponse) {
        guard let i = requestList.firstIndex(where: { $0.id == requestID }), requestList[i].state == .pending else { return }
        switch response {
        case .accept:
            requestList[i].state = .accepted
            let r = requestList[i]
            if !conversationList.contains(where: { $0.personID == r.personID }) {
                conversationList.append(Conversation(personID: r.personID, projectTitle: projectList.first { $0.id == r.projectID }?.title,
                                                     messages: [ChatMessage(text: "Request accepted. Welcome to the Crew!", fromMe: true)]))
            }
        case .decline: requestList[i].state = .declined
        case .withdraw: requestList[i].state = .withdrawn
        }
    }

    public func removeFromCrew(_ personID: UUID) {
        for i in requestList.indices where requestList[i].personID == personID && requestList[i].state == .accepted { requestList[i].state = .ended }
        conversationList.removeAll { $0.personID == personID }
    }

    // MARK: ConversationRepository
    public func conversations() -> [Conversation] { conversationList }
    public func send(_ text: String, to personID: UUID) {
        guard let i = conversationList.firstIndex(where: { $0.personID == personID }) else { return }
        conversationList[i].messages.append(ChatMessage(text: text, fromMe: true))
    }

    // MARK: SafetyRepository
    public func blockedPeople() -> Set<UUID> { blockedSet }
    public func block(_ personID: UUID) {
        blockedSet.insert(personID)
        for i in requestList.indices where requestList[i].personID == personID && requestList[i].state == .pending {
            requestList[i].state = requestList[i].direction == .outgoing ? .withdrawn : .declined
        }
    }
    public func unblock(_ personID: UUID) { blockedSet.remove(personID) }
    public func report(personID: UUID, reason: ReportReason, context: String) {}
}
#endif
