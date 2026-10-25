import Foundation
import KizukiCore
import KizukiDesignSystem
import KizukiTestSupport
import Testing
import UIKit

@MainActor
struct PrototypeStoreTests {
    private func loadedStore() async -> AppStore {
        let store = AppStore(dependencies: FixtureBackend.dependencies())
        await store.load()
        return store
    }

    @Test func fixtureSetMatchesTheBrief() async {
        let store = await loadedStore()
        #expect(store.people.count + 1 == 20)
        #expect(store.projects.count == 10)
        // Every state a fixture can start in. `.ended` only appears after someone is removed from the Crew.
        #expect(Set(store.requests.map(\.state)) == Set(RequestState.allCases).subtracting([.ended]))
        #expect(store.requests.count == 14)
        #expect(store.conversations.count == 3)
        #expect(store.crew.count == 3)
    }

    @Test func acceptingMovesThePersonIntoCrewAndCreatesAChat() async throws {
        let store = await loadedStore()
        let incoming = try #require(store.requests(.incoming).first { $0.state == .pending })
        #expect(!store.isInCrew(incoming.personID))
        #expect(store.conversation(with: incoming.personID) == nil)
        let joined = await store.respond(to: incoming.id, with: .accept)
        #expect(joined == incoming.personID)
        #expect(store.isInCrew(incoming.personID))
        #expect(store.conversation(with: incoming.personID) != nil)
        // A second accept on the same request does nothing.
        #expect(await store.respond(to: incoming.id, with: .accept) == nil)
    }

    @Test func decliningDoesNotOpenChat() async throws {
        let store = await loadedStore()
        let incoming = try #require(store.requests(.incoming).first { $0.state == .pending })
        await store.respond(to: incoming.id, with: .decline)
        #expect(!store.isInCrew(incoming.personID))
        #expect(store.conversation(with: incoming.personID) == nil)
    }

    @Test func blockingHidesAndRemovesFromCrew() async throws {
        let store = await loadedStore()
        let crewMember = try #require(store.crew.first)
        await store.block(crewMember.id)
        #expect(!store.isInCrew(crewMember.id))
        #expect(store.conversation(with: crewMember.id) == nil)
        #expect(!store.visiblePeopleRecommendations.contains { $0.item.id == crewMember.id })
        await store.unblock(crewMember.id)
        #expect(store.isInCrew(crewMember.id))
    }

    @Test func requestCarriesNoPaymentAndDuplicatesAreIgnored() async throws {
        let store = await loadedStore()
        let project = try #require(store.projects.first { $0.status == .published && $0.ownerID != store.me.id && !$0.memberIDs.contains(store.me.id)
            && store.pendingRequest(for: $0.ownerID, project: $0.id) == nil })
        let request = NewRequest(personID: project.ownerID, projectID: project.id, role: "Editor", timeCommitment: "5–10 hours / week", note: "Hi")
        let before = store.requests.count
        await store.sendRequest(request)
        await store.sendRequest(request)
        #expect(store.requests.count == before + 1)
    }

    // MARK: Round 1 revisions (decisions 51-57)

    @Test func removeFromCrewClosesTheChatButDoesNotBlock() async throws {
        let store = await loadedStore()
        let member = try #require(store.crew.first)
        let others = store.crew.filter { $0.id != member.id }.map(\.id)
        #expect(store.conversation(with: member.id) != nil)
        await store.removeFromCrew(member.id)
        #expect(!store.isInCrew(member.id))
        #expect(store.conversation(with: member.id) == nil)
        #expect(store.chatList.allSatisfy { $0.personID != member.id })
        // Not a block: still visible, can be found and asked again. The connection is kept as history.
        #expect(!store.isBlocked(member.id))
        #expect(store.person(member.id) != nil)
        #expect(store.requests.contains { $0.personID == member.id && $0.state == .ended })
        #expect(!store.requests.contains { $0.personID == member.id && $0.state == .accepted })
        // The rest of the Crew is untouched.
        #expect(Set(store.crew.map(\.id)) == Set(others))
        // A second removal does nothing; a fresh Wish to Collab is allowed.
        await store.removeFromCrew(member.id)
        let before = store.requests.count
        await store.sendRequest(NewRequest(personID: member.id, projectID: nil, role: "Director", timeCommitment: "5–10 hours / week", note: "Again?"))
        #expect(store.requests.count == before + 1)
    }

    @Test func wishToCollabWorksWithoutAProject() async throws {
        let store = await loadedStore()
        let target = try #require(store.people.first { p in !store.requests.contains { $0.personID == p.id } })
        #expect(store.pendingRequest(for: target.id, project: nil) == nil)
        let request = NewRequest(personID: target.id, projectID: nil, role: "Director", timeCommitment: "5–10 hours / week", note: "No project yet.")
        await store.sendRequest(request)
        let sent = try #require(store.pendingRequest(for: target.id, project: nil))
        #expect(sent.kind == .wishToCollab)
        #expect(sent.kind.label == "Wish to Collab")
        #expect(sent.projectID == nil)
        await store.sendRequest(request)
        #expect(store.requests.filter { $0.personID == target.id }.count == 1)
        // Fixtures include both kinds, both ways.
        #expect(store.requests.contains { $0.kind == .wishToCollab && $0.direction == .incoming })
        #expect(store.requests.contains { $0.kind == .wishToCollab && $0.direction == .outgoing })
        #expect(store.requests.contains { $0.kind == .joinProject && $0.kind.label == "Join project" })
    }

    @Test func acceptingAWishOpensAChatWithNoProject() async throws {
        let store = await loadedStore()
        let wish = try #require(store.requests(.incoming).first { $0.state == .pending && $0.kind == .wishToCollab })
        let joined = await store.respond(to: wish.id, with: .accept)
        #expect(joined == wish.personID)
        let chat = try #require(store.conversation(with: wish.personID))
        #expect(chat.projectTitle == nil)
    }

    @Test func availabilityIsPublicOnEveryProfile() async {
        let store = await loadedStore()
        #expect(Set(store.people.map(\.availability)) == Set(Availability.allCases))
        #expect(store.me.availability == store.own.availability)
    }

    @Test func searchContentIsPhotosAndShortVideosOnly() async {
        let store = await loadedStore()
        let videos = store.photos.filter(\.isVideo)
        #expect(!videos.isEmpty && videos.count < store.photos.count)
        #expect(videos.allSatisfy { ($0.videoSeconds ?? 0) > 0 && ($0.videoSeconds ?? 0) <= 60 && $0.durationLabel != nil })
        #expect(CollabPhoto(authorID: UUID(), caption: "", tags: [], artSeed: 0, videoSeconds: 27).durationLabel == "0:27")
        #expect(CollabPhoto(authorID: UUID(), caption: "", tags: [], artSeed: 0).durationLabel == nil)
    }

    @Test func getDiscoveredChecklistTracksTheProfile() async {
        let store = await loadedStore()
        let steps = store.discoverySteps
        #expect(steps.count == 5)
        #expect(steps.first { $0.kind == .bio }?.done == false)
        #expect(store.discoveryDoneCount == 4)
        store.updateOwn { $0.person.bio = "Making little films about big feelings." }
        #expect(store.discoveryDoneCount == 5)
    }

    @Test func kizukiIconAssetsShipInTheBundle() {
        for icon in KizukiIcon.allCases { #expect(icon.uiImage != nil, "missing asset \(icon.rawValue)") }
        #expect(KizukiIcon.allCases.count == 11)
    }

    @Test func galleryScriptListsEveryScreenId() throws {
        // #filePath = <repo>/ios/Tests/PrototypeStoreTests.swift
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: repo.appendingPathComponent("scripts/screenshot-gallery.sh"), encoding: .utf8)
        let expected = ["splash", "login", "eligibility", "onb-handle", "onb-ready", "home", "request-form", "search-post", "suki-sent", "suki-empty", "create-project",
                        "my-project-owner", "profile-other", "chat", "settings-delete"]
        for id in expected { #expect(script.contains(id), "missing \(id)") }
    }
}
