import Foundation
import KizukiCore
import KizukiInfrastructure
import KizukiTestSupport
import Testing

struct LiveDependenciesTests {
    @Test func fixtureAndLiveUseSameProtocolsWithoutLiveFixtureFallback() async throws {
        let fixtures = Dependencies.fixture
        #expect(try await fixtures.directory.people().count > 0)
        let configuration = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321",
                                                 publishableKey: "sb_publishable_local_test_only")
        let live = Dependencies.live(configuration: configuration)
        let own = FixtureData.ownProfile
        let project = FixtureData.projects[0]
        let id = UUID()
        let request = NewRequest(personID: id, projectID: nil, role: "Editor", timeCommitment: "5–10 hours / week", note: "Test")
        let operations: [@Sendable () async throws -> Void] = [
            { _ = try await live.own.own() }, { try await live.own.save(own) },
            { _ = try await live.directory.people() }, { _ = try await live.directory.collabPhotos() },
            { _ = try await live.directory.recommendedPeople() }, { _ = try await live.directory.recommendedProjects() },
            { try await live.directory.postCollab(caption: "Test", tags: []) },
            { _ = try await live.projects.projects() }, { try await live.projects.save(project) },
            { _ = try await live.requests.requests() }, { try await live.requests.send(request) },
            { try await live.requests.respond(to: id, with: .accept) }, { try await live.requests.removeFromCrew(id) },
            { _ = try await live.conversations.conversations() }, { try await live.conversations.send("Test", to: id) },
            { _ = try await live.safety.blockedPeople() }, { try await live.safety.block(id) },
            { try await live.safety.unblock(id) }, { try await live.safety.report(personID: id, reason: .spam, context: "Test") }
        ]
        for operation in operations {
            do {
                try await operation()
                Issue.record("Live call returned invented success")
            } catch let error as LiveRepositoryError {
                guard case .notYetAvailable(let feature) = error else { return }
                #expect(!feature.isEmpty)
            } catch { Issue.record("Expected explicit not-yet-available error") }
        }
    }
}
