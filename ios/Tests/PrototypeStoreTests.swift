import Foundation
import KizukiCore
import KizukiDesignSystem
import KizukiTestSupport
import Testing
import UIKit

@MainActor
struct PrototypeStoreTests {
    @Test func feedPromptsReflectOwnedDraftsPendingRequestsAndIncompleteProfiles() async throws {
        let store = AppStore(dependencies: FixtureBackend.dependencies())
        #expect(store.feedPrompts.isEmpty)
        await store.load()
        let draft = try #require(store.projects([.draft]).first { store.isOwner($0) })
        #expect(store.feedPrompts.contains(.finishProject(draft.id)))
        let pending = store.requests(.incoming).filter { $0.state == .pending }
        #expect(store.feedPrompts.contains(.reviewRequests(pending.count)))
        #expect(store.feedPrompts.contains(.completeProfile))
        #expect(Set(store.feedPrompts.map(\.id)).count == store.feedPrompts.count)
        #expect(!store.feedPrompts.contains { $0.id == "crew" })
        for var project in store.projects([.draft]) where store.isOwner(project) {
            project.status = .published
            await store.saveProject(project)
        }
        #expect(!store.feedPrompts.contains { $0.id == "draft" })
        for request in pending { await store.respond(to: request.id, with: .decline) }
        #expect(!store.feedPrompts.contains { $0.id == "requests" })
        #expect(await store.saveProfileBasics(name: store.me.name, bio: "Making films with kind people.", city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open))
        #expect(store.feedPrompts.isEmpty)
    }

    @Test func feedPromptsRespectSafetyAndStopAfterFirstMessage() async throws {
        let store = await loadedStore()
        let pending = store.requests(.incoming).filter { $0.state == .pending }
        let request = try #require(pending.first)
        await store.respond(to: request.id, with: .accept)
        #expect(store.feedPrompts.contains(.startConversation(request.personID)))
        await store.sendMessage("Hello!", to: request.personID)
        #expect(!store.feedPrompts.contains(.startConversation(request.personID)))
        for request in pending.dropFirst() { await store.block(request.personID) }
        #expect(!store.feedPrompts.contains { $0.id == "requests" })
        let anotherStore = await loadedStore()
        await anotherStore.respond(to: request.id, with: .accept)
        await anotherStore.block(request.personID)
        #expect(!anotherStore.feedPrompts.contains(.startConversation(request.personID)))
    }

    @Test func inspirationFeedDoesNotNudgeCollaboration() async {
        let store = await loadedStore()
        #expect(await store.saveProfileBasics(name: store.me.name, bio: "Collecting creative inspiration.", city: store.me.city, roles: [], availability: .low, compensation: .open, goal: .explore))
        #expect(store.feedPrompts.isEmpty)
    }

    @Test func widgetVisibilitySurvivesColdLoadWithoutDeletingLinks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = AppStore(dependencies: FixtureBackend.dependencies(storageURL: url))
        await store.load()
        let links = [
            ProfileLink(kind: .bandcamp, title: "Album", url: "https://artist.bandcamp.com/album/example", isEnabled: false),
            ProfileLink(kind: .soundcloud, title: "Track", url: "https://soundcloud.com/artist/track", isEnabled: false),
            ProfileLink(kind: .tiktok, title: "Videos", url: "https://www.tiktok.com/@artist", isEnabled: false)
        ]
        #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: links))
        let restored = await FixtureBackend(storageURL: url).own()
        #expect(restored.person.links == links)
        #expect(restored.person.visibleLinks.isEmpty)
        let enabled = links.map { ProfileLink(kind: $0.kind, title: $0.title, url: $0.url) }
        #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: enabled))
        #expect(await FixtureBackend(storageURL: url).own().person.visibleLinks == enabled)
    }

    @Test func legacyLinksDefaultToVisibleAndDemoLinksCanBeHidden() async throws {
        let legacy = try JSONDecoder().decode(ProfileLink.self, from: Data(#"{"kind":"SoundCloud","title":"Track","url":"https://soundcloud.com/artist/track"}"#.utf8))
        #expect(legacy.isEnabled)
        let store = await loadedStore()
        let hidden = store.me.links.map { ProfileLink(kind: $0.kind, title: $0.title, url: $0.url, isEnabled: false) }
        #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: hidden))
        #expect(store.me.visibleLinks.isEmpty)
        #expect(store.me.links == hidden)
    }

    @Test func tiktokAllowsOnlyOfficialHTTPSDestinations() {
        for url in ["https://www.tiktok.com/@artist", "https://www.tiktok.com/@artist/video/123456789", "https://vm.tiktok.com/abc/", "https://vt.tiktok.com/abc/"] {
            let descriptor = PortfolioWidgetDescriptor(link: ProfileLink(kind: .tiktok, title: "TikTok", url: url))
            #expect(descriptor.state == .linkOnly)
            #expect(descriptor.externalURL != nil)
            #expect(descriptor.embedURL == nil)
        }
        for url in ["http://tiktok.com/@artist", "https://tiktok.com.evil.test/@artist", "https://evil.tiktok.com/@artist", "https://user@tiktok.com/@artist", "https://tiktok.com:8080/@artist", "javascript:alert(1)"] {
            #expect(PortfolioWidgetDescriptor(link: ProfileLink(kind: .tiktok, title: "TikTok", url: url)).state == .invalid)
        }
    }
    @Test func expandedTaxonomyIncludesPainterAndExistingCreativeRoles() {
        #expect(Realm.visualArts.roleOptions.contains("Painter"))
        #expect(Realm.visualArts.roleOptions.contains("Graphic designer"))
        #expect(Realm.visualArts.roleOptions.contains("Ceramicist"))
        for realm in Realm.allCases {
            #expect(Set(realm.roleOptions).count == realm.roleOptions.count)
        }
        for person in FixtureData.people {
            #expect(RoleSelection.isValid(person.roles, realm: person.realm))
        }
    }

    @Test func inspirationCompletesWithoutInventingRolesOrAvailability() async {
        let store = await loadedStore()
        var draft = store.own
        draft.goal = .explore
        draft.person.roles = []
        draft.person.bio = "Collecting creative inspiration."
        #expect(await store.completeOnboarding(draft))
        #expect(!store.me.acceptsCollaboration)
        #expect(store.me.roles.isEmpty)
        #expect(store.isProfileComplete)
        #expect(!store.discoverySteps.contains { $0.kind == .roles })
        #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: ["Director"], availability: .low, compensation: .open, goal: .collaborate))
        #expect(store.me.acceptsCollaboration)
        #expect(store.own.goal == .collaborate)
    }

    @Test func legacyInspirationProfilesDoNotAdvertiseCollaboration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        var profile = FixtureData.ownProfile
        profile.goal = .explore
        profile.person.collaborationEnabled = nil
        try await FixtureBackend(storageURL: url).save(profile)
        let restored = await FixtureBackend(storageURL: url).own()
        #expect(!restored.person.acceptsCollaboration)
        #expect(restored.person.roles == profile.person.roles)
    }

    @Test func widgetURLsRejectUntrustedOriginsAndNeverInventBandcampIDs() throws {
        for url in ["http://youtube.com/watch?v=dQw4w9WgXcQ", "https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ", "https://user@youtube.com/watch?v=dQw4w9WgXcQ", "javascript:alert(1)", "https://youtube.com:8443/watch?v=dQw4w9WgXcQ", "https://youtube.example/demo"] {
            let widget = PortfolioWidgetDescriptor(link: ProfileLink(kind: .youtube, title: "Video", url: url))
            #expect(widget.state == .invalid)
            #expect(widget.externalURL == nil)
            #expect(widget.embedURL == nil)
        }
        let youtube = PortfolioWidgetDescriptor(link: ProfileLink(kind: .youtube, title: "Video", url: "https://youtu.be/dQw4w9WgXcQ"))
        #expect(youtube.state == .embedAvailable)
        #expect(youtube.embedURL?.host == "www.youtube-nocookie.com")
        #expect(youtube.requiresPlaybackConsent)
        let soundcloud = PortfolioWidgetDescriptor(link: ProfileLink(kind: .soundcloud, title: "Track", url: "https://soundcloud.com/artist/track?tracking=removed"))
        #expect(soundcloud.embedURL?.host == "w.soundcloud.com")
        #expect(soundcloud.embedURL?.absoluteString.contains("auto_play=false") == true)
        let bandcamp = PortfolioWidgetDescriptor(link: ProfileLink(kind: .bandcamp, title: "Album", url: "https://artist.bandcamp.com/album/example"))
        #expect(bandcamp.state == .metadataRequired)
        #expect(bandcamp.embedURL == nil)
        let instagram = PortfolioWidgetDescriptor(link: ProfileLink(kind: .instagram, title: "Work", url: "https://www.instagram.com/artist/"))
        #expect(instagram.state == .linkOnly)
        #expect(!instagram.requiresPlaybackConsent)
    }

    @Test func demoPhotosShipAndNoPhotoProfilesKeepFallbacks() {
        for name in Artwork.stockAssets + ["StockPortraitOne", "StockPortraitTwo"] {
            #expect(Artwork.hasStockAsset(named: name))
        }
        #expect(FixtureData.people[0].portraitAsset == nil)
        #expect(FixtureData.people[1].portraitAsset == "StockPortraitTwo")
    }

    @Test func providerIconsShipForEveryWidget() {
        for kind in LinkKind.allCases {
            #expect(ProviderIcon.hasAsset(kind.iconAsset))
        }
    }

    @Test func portfolioURLInputNormalizesWithoutWeakeningOriginValidation() {
        for kind in LinkKind.allCases {
            #expect(kind.normalizedPortfolioURL(" \n" + kind.exampleURL + "\n ") == "https://" + kind.exampleURL)
            #expect(kind.normalizedPortfolioURL("https://evil.test/" + kind.exampleURL) == nil)
            #expect(kind.normalizedPortfolioURL("http://" + kind.exampleURL) == nil)
        }
        #expect(LinkKind.youtube.normalizedPortfolioURL("HTTPS://WWW.YOUTUBE.COM/@artist") == "https://www.youtube.com/@artist")
        for url in ["", "   ", "https://youtube.com.evil.test/video", "https://youtube.com@evil.test/video", "https://user@youtube.com/video", "https://youtube.com:443/video", "javascript:alert(1)", "file:///youtube.com/video", "youtube.com/a b", "youtube.com\\@evil.test", "//youtube.com/video"] {
            #expect(LinkKind.youtube.normalizedPortfolioURL(url) == nil)
        }
    }

    @Test func schemelessWidgetEditsSaveAndRetainHiddenState() async {
        let store = await loadedStore()
        let links = [ProfileLink(kind: .soundcloud, title: "Track", url: " soundcloud.com/artist/track\n", isEnabled: false)]
        #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: links))
        await store.load()
        #expect(store.me.links.first?.url == "https://soundcloud.com/artist/track")
        #expect(store.me.links.first?.isEnabled == false)
    }

    @Test func portfolioEditsValidateAndPersistWithoutChangingMatchingConsent() async {
        let store = await loadedStore()
        let before = store.own
        let valid = ProfileLink(kind: .youtube, title: "Film", url: "https://youtu.be/dQw4w9WgXcQ")
        let invalid = ProfileLink(kind: .youtube, title: "Film", url: "https://youtube.com.evil.test/video")
        #expect(!(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: [invalid])))
        #expect(store.own == before)
        #expect(!(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: [valid, valid])))
        #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: .mid, compensation: .open, links: [valid]))
        await store.load()
        #expect(store.me.links == [valid])
        #expect(store.own.useTasteForMatching == before.useTasteForMatching)
        #expect(store.own.useFavouritesForMatching == before.useFavouritesForMatching)
    }
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

    @Test func availabilityBucketsAreDistinctAndKeepStoredValues() throws {
        #expect(Availability.low.level == .low)
        #expect(Availability.mid.level == .medium)
        #expect(Availability.high.level == .high)
        #expect(Set(Availability.allCases.map(\.hoursLabel)).count == Availability.allCases.count)
        #expect(Set(Availability.allCases.map(\.levelLabel)).count == Availability.allCases.count)
        #expect(Availability.low.hoursLabel == "Under 5 hours / week")
        #expect(Availability.mid.hoursLabel == "5–9 hours / week")
        #expect(Availability.high.hoursLabel == "10+ hours / week")
        #expect(Availability.low.levelLabel == "Low availability")
        #expect(Availability.mid.levelLabel == "Medium availability")
        #expect(Availability.high.levelLabel == "High availability")
        for (stored, expected) in [("Under 5 hours / week", Availability.low), ("5–10 hours / week", .mid), ("10+ hours / week", .high)] {
            #expect(try JSONDecoder().decode(Availability.self, from: JSONEncoder().encode(stored)) == expected)
            #expect(try JSONDecoder().decode(String.self, from: JSONEncoder().encode(expected)) == stored)
        }
    }

    @Test func availabilityEditsSaveAndReloadForEveryBucket() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = AppStore(dependencies: FixtureBackend.dependencies(storageURL: url))
        await store.load()
        for availability in Availability.allCases {
            #expect(await store.saveProfileBasics(name: store.me.name, bio: store.me.bio, city: store.me.city, roles: store.me.roles, availability: availability, compensation: store.own.compensation))
            #expect(store.own.availability == availability)
            #expect(store.me.availability == availability)
            let reopened = AppStore(dependencies: FixtureBackend.dependencies(storageURL: url))
            await reopened.load()
            #expect(reopened.own.availability == availability)
            #expect(reopened.me.availability == availability)
            #expect(reopened.me.availability.level == availability.level)
        }
    }

    @Test func legacyFavouritesStillLoadButNeverShapeSuggestions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let backend = FixtureBackend(storageURL: url)
        var profile = await backend.own()
        profile.favourites = ["Perfect Days", "Nala Sinephro"]
        profile.person.favourites = ["Perfect Days"]
        profile.showFavourites = true
        profile.useFavouritesForMatching = true
        try await backend.save(profile)
        let reopened = FixtureBackend(storageURL: url)
        #expect(await reopened.own() == profile)
        let people = await reopened.recommendedPeople()
        #expect(!people.isEmpty)
        #expect(!people.contains { $0.reasons.contains { $0.localizedCaseInsensitiveContains("favourite") } })
        #expect(!(await reopened.recommendedProjects()).contains { $0.reasons.contains { $0.localizedCaseInsensitiveContains("favourite") } })
        #expect(FixtureData.people.allSatisfy { $0.favourites.isEmpty })
        #expect(FixtureData.ownProfile.favourites.isEmpty)
        #expect(!FixtureData.ownProfile.showFavourites && !FixtureData.ownProfile.useFavouritesForMatching)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: repo.appendingPathComponent("scripts/screenshot-gallery.sh"), encoding: .utf8)
        #expect(!script.contains("onb-favourites"))
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
        #expect(steps.count == 4)
        #expect(steps.first { $0.kind == .bio }?.done == false)
        #expect(store.discoveryDoneCount == 3)
        store.updateOwn { $0.person.bio = "Making little films about big feelings." }
        #expect(store.discoveryDoneCount == 4)
        #expect(store.isProfileComplete)
    }

    @Test func emptyAndWhitespaceProfilesRemainIncomplete() async {
        let store = AppStore(dependencies: FixtureBackend.dependencies())
        #expect(store.discoveryDoneCount == 0)
        #expect(!store.isProfileComplete)
        await store.load()
        store.updateOwn {
            $0.person.name = " \n\t "
            $0.person.bio = String(repeating: " ", count: 20)
            $0.person.city = "\n "
            $0.person.roles = [" "]
        }
        #expect(store.discoveryDoneCount == 0)
        store.updateOwn { $0.person.name = "Mika" }
        #expect(store.discoveryDoneCount == 1)
        #expect(!store.isProfileComplete)
    }

    @Test func completionRejectsInvalidBasicsAndRoles() async {
        let store = await loadedStore()
        store.updateOwn {
            $0.person.name = "---"
            $0.person.bio = ".........."
            $0.person.city = "12345"
            $0.person.roles = ["Unknown role"]
        }
        #expect(store.discoveryDoneCount == 0)
        store.updateOwn { $0.person.roles = ["Director", "Director"] }
        #expect(store.discoverySteps.first { $0.kind == .roles }?.done == false)
        store.updateOwn { $0.person.roles = [" Director "]; $0.person.bio = "short" }
        #expect(store.discoveryDoneCount == 1)
    }

    @Test func savedBasicsCompleteWithoutEnrichmentAndSurviveReload() async throws {
        let backend = FixtureBackend()
        var profile = await backend.own()
        profile.person.links = []
        profile.person.favourites = []
        profile.favourites = []
        profile.useTasteForMatching = false
        profile.useFavouritesForMatching = false
        profile.showFavourites = false
        try await backend.save(profile)
        let deps = Dependencies(sessions: backend, profiles: backend, own: backend, directory: backend, projects: backend, requests: backend, conversations: backend, safety: backend)
        let store = AppStore(dependencies: deps)
        await store.load()
        #expect(!store.isProfileComplete)
        #expect(await store.saveProfileBasics(name: " Mika \n", bio: " Making films with friends. \n", city: " Berlin \n", roles: [" Director "], availability: .high, compensation: .passion))
        #expect(store.isProfileComplete)
        #expect(store.me.name == "Mika")
        #expect(store.me.bio == "Making films with friends.")
        #expect(store.me.city == "Berlin")
        #expect(store.me.roles == ["Director"])
        #expect(store.me.availability == .high)
        let reopened = AppStore(dependencies: deps)
        await reopened.load()
        #expect(reopened.isProfileComplete)
        #expect(reopened.me.links.isEmpty)
        #expect(reopened.own.favourites.isEmpty)
        #expect(!reopened.own.useTasteForMatching)
        #expect(!reopened.own.useFavouritesForMatching)
        #expect(!reopened.own.showFavourites)
        #expect(reopened.own.compensation == .passion)
        #expect(await reopened.saveProfileBasics(name: "Mika", bio: " ", city: "Berlin", roles: ["Director"], availability: .high, compensation: .passion))
        #expect(!reopened.isProfileComplete)
        await reopened.load()
        #expect(!reopened.isProfileComplete)
        #expect(await reopened.saveProfileBasics(name: " \n", bio: " \t", city: " ", roles: [], availability: .mid, compensation: .open))
        #expect(reopened.discoveryDoneCount == 0)
        #expect(reopened.me.name.isEmpty && reopened.me.bio.isEmpty && reopened.me.city.isEmpty)
        await reopened.load()
        #expect(reopened.discoveryDoneCount == 0)
    }

    @Test func completionDoesNotRequireAPhotoOrPost() async {
        let store = AppStore(dependencies: FixtureBackend.dependencies())
        #expect(await store.saveProfileBasics(name: "Mika", bio: "Making films with friends.", city: "Berlin", roles: ["Director"], availability: .mid, compensation: .open))
        #expect(store.isProfileComplete)
        #expect(store.photos.isEmpty)
        #expect(store.me.links.isEmpty)
        #expect(store.own.favourites.isEmpty)
    }

    @Test func failedProfileSaveKeepsSavedStateIncomplete() async {
        let backend = FixtureBackend()
        let deps = Dependencies(sessions: backend, profiles: backend, own: RejectingProfileRepository(), directory: backend, projects: backend, requests: backend, conversations: backend, safety: backend)
        let store = AppStore(dependencies: deps)
        await store.load()
        let before = store.own
        #expect(await store.saveProfileBasics(name: "Mika", bio: "Making films with friends.", city: "Berlin", roles: ["Director"], availability: .high, compensation: .passion) == false)
        #expect(store.own == before)
        #expect(!store.isProfileComplete)
        await store.load()
        #expect(store.own == before)
        #expect(!store.isProfileComplete)
    }

    @Test func kizukiIconAssetsShipInTheBundle() {
        for icon in KizukiIcon.allCases { #expect(icon.uiImage != nil, "missing asset \(icon.rawValue)") }
        #expect(KizukiIcon.allCases.count == 11)
    }

    @Test func originalBrandAssetsKeepTheirExportedProportions() throws {
        let mark = try #require(KizukiIcon.kMark.uiImage)
        let feed = try #require(KizukiIcon.feedLogo.uiImage)
        let wordmark = try #require(KizukiIcon.wordmark.uiImage)
        #expect(abs(mark.size.width / mark.size.height - 145.0 / 278.0) < 0.01)
        #expect(abs(feed.size.width / feed.size.height - 22.0 / 42.2346) < 0.01)
        #expect(abs(wordmark.size.width / wordmark.size.height - 237.0 / 92.0) < 0.01)
        let messages = try #require(KizukiIcon.messages.uiImage)
        #expect(messages.size.width == messages.size.height)
    }

    @Test func figmaFontsAndIllustrationsShipWithoutFallbacks() {
        KizukiFonts.register()
        for weight in KizukiTheme.PoppinsWeight.allCases {
            let name = "Poppins-\(weight.rawValue)"
            #expect(UIFont(name: name, size: 15)?.fontName == name, "missing font \(name)")
        }
        #expect(UIFont(name: "DMMono-Medium", size: 12)?.fontName == "DMMono-Medium")
        for illustration in KizukiIllustration.allCases {
            #expect(illustration.uiImage != nil, "missing illustration \(illustration.rawValue)")
        }
    }

    @Test func galleryScriptListsEveryScreenId() throws {
        // #filePath = <repo>/ios/Tests/PrototypeStoreTests.swift
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: repo.appendingPathComponent("scripts/screenshot-gallery.sh"), encoding: .utf8)
        let expected = ["splash", "login", "eligibility", "onb-handle", "onb-primer-location", "home", "request-form", "search-post", "suki-sent", "suki-empty", "create-project",
                        "my-project-owner", "profile-other", "chat", "settings-delete"]
        for id in expected { #expect(script.contains(id), "missing \(id)") }
    }

    @Test func fourRolesShareSelectionRulesAndStableMainOrder() throws {
        for realm in Realm.allCases {
            var roles = [realm.roleOptions[0]]
            for role in realm.roleOptions.dropFirst().prefix(3) { roles = RoleSelection.toggling(role, in: roles, realm: realm) }
            #expect(roles == Array(realm.roleOptions.prefix(4)))
            #expect(RoleSelection.toggling(realm.roleOptions[4], in: roles, realm: realm) == roles)
            #expect(RoleSelection.toggling("Invalid", in: roles, realm: realm) == roles)
            #expect(!RoleSelection.isValid(roles + [roles[0]], realm: realm))
            #expect(!RoleSelection.isValid([roles[0], roles[0]], realm: realm))
            let promoted = RoleSelection.promoting(roles[2], in: roles)
            #expect(promoted == [roles[2], roles[0], roles[1], roles[3]])
            #expect(RoleSelection.toggling(promoted[0], in: promoted, realm: realm) == [roles[0], roles[1], roles[3]])
            #expect(RoleSelection.toggling(roles[0], in: [roles[0]], realm: realm) == [roles[0]])
            var person = FixtureData.ownProfile.person
            person.realm = realm
            person.roles = promoted
            #expect(try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person)).roles == promoted)
            for role in roles { #expect(RoleSelection.score(roles, matching: [role]) > 0) }
            #expect(RoleSelection.score(roles, matching: [roles[0]]) > RoleSelection.score(roles, matching: Array(roles.dropFirst())))
        }
    }

    @Test func localProfileRestoresAllFieldsAndCompletionAcrossNewBackends() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let backend = FixtureBackend(storageURL: url)
        var profile = await backend.own()
        profile.person.roles = ["Editor", "Director", "Producer", "Writer"]
        profile.person.bio = "Making films with friends."
        profile.onboardingCompleted = true
        profile.availability = .high
        profile.person.availability = .high
        profile.compensation = .passion
        profile.workMode = .remote
        profile.showFavourites = false
        profile.useFavouritesForMatching = false
        profile.useTasteForMatching = false
        profile.favourites = ["Aftersun"]
        try await backend.save(profile)
        #expect(await FixtureBackend(storageURL: url).own() == profile)
        #expect(await FixtureBackend().own() == FixtureData.ownProfile)
        let store = AppStore(dependencies: FixtureBackend.dependencies(storageURL: url))
        await store.load()
        #expect(store.isProfileComplete)
        #expect(store.own.onboardingCompleted == true)
        let before = store.own
        #expect(!(await store.saveProfileBasics(name: "Changed", bio: "Changed biography", city: "Berlin", roles: Array(Realm.film.roleOptions.prefix(5)), availability: .low, compensation: .paid)))
        #expect(store.own == before)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        object.removeValue(forKey: "onboardingCompleted")
        let legacy = try JSONDecoder().decode(OwnProfile.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.onboardingCompleted == nil)
        #expect(legacy.person.roles == profile.person.roles)
        try Data("corrupt".utf8).write(to: url)
        #expect(await FixtureBackend(storageURL: url).own() == FixtureData.ownProfile)
        try JSONSerialization.data(withJSONObject: ["version": 99, "profile": object]).write(to: url)
        #expect(await FixtureBackend(storageURL: url).own() == FixtureData.ownProfile)
    }

    @Test func atomicWriteFailureKeepsProfileAndOnboardingUnchanged() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("file prevents directory creation".utf8).write(to: url)
        let store = AppStore(dependencies: FixtureBackend.dependencies(storageURL: url.appendingPathComponent("profile.json")))
        await store.load()
        let before = store.own
        #expect(!(await store.completeOnboarding(before)))
        #expect(!(await store.saveProfileBasics(name: "Changed", bio: "Changed biography", city: "Berlin", roles: ["Editor"], availability: .low, compensation: .paid)))
        #expect(store.own == before)
        await store.load()
        #expect(store.own == before)
    }

    @Test func roleRecommendationsRankMainAboveSecondaryAndKeepFilters() async throws {
        let backend = FixtureBackend()
        var profile = await backend.own()
        profile.person.roles = ["Director", "Editor", "Producer", "Writer"]
        try await backend.save(profile)
        for role in profile.person.roles {
            await backend.save(Project(id: UUID(), ownerID: FixtureData.personID(1), title: role, realm: .film, rolesNeeded: [role], summary: "Role ranking", status: .published))
        }
        let projects = await backend.recommendedProjects()
        let scores = projects.map { RoleSelection.score(profile.person.roles, matching: $0.item.rolesNeeded) }
        #expect(scores == scores.sorted(by: >))
        #expect(projects.firstIndex { $0.item.title == "Director" }! < projects.firstIndex { $0.item.title == "Editor" }!)
        #expect(projects.allSatisfy { $0.item.status == .published && $0.item.ownerID != profile.person.id && !$0.item.memberIDs.contains(profile.person.id) })
        let people = await backend.recommendedPeople()
        let peopleScores = people.map { RoleSelection.score(profile.person.roles, matching: $0.item.roles) }
        #expect(peopleScores == peopleScores.sorted(by: >))
    }

    @Test func everyFixtureProfileHasUniqueLinkIDs() {
        for person in FixtureData.people {
            let ids = person.links.map(\.id)
            #expect(Set(ids).count == ids.count, "duplicate link IDs for \(person.name): \(ids)")
        }
    }

    @Test func tasteSwitchControlsSharedTasteReasonsInBothLists() async throws {
        let backend = FixtureBackend()
        let sharedTaste: (Recommendation<Person>) -> Bool = { $0.reasons.contains("Shared taste") }
        let projectTaste: (Recommendation<Project>) -> Bool = { $0.reasons.contains("Shared taste") }
        var own = await backend.own()
        own.useTasteForMatching = true
        try await backend.save(own)
        #expect(await backend.recommendedPeople().contains(where: sharedTaste))
        #expect(await backend.recommendedProjects().contains(where: projectTaste))
        own.useTasteForMatching = false
        try await backend.save(own)
        #expect(!(await backend.recommendedPeople().contains(where: sharedTaste)))
        #expect(!(await backend.recommendedProjects().contains(where: projectTaste)))
    }
}

private struct RejectingProfileRepository: OwnProfileRepository {
    enum SaveError: Error { case rejected }
    func own() async throws -> OwnProfile { FixtureData.ownProfile }
    func save(_ profile: OwnProfile) async throws { throw SaveError.rejected }
}
