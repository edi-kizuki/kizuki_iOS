import Foundation
import KizukiCore
import Testing

private struct SessionStub: SessionRepository {
    let stream: AsyncStream<SessionEvent>
    var failSignOut = false
    func events() async -> AsyncStream<SessionEvent> { stream }
    func signOut() async throws { if failSignOut { throw StubError.failed } }
}
private enum StubError: Error { case failed }
private actor DeferredProfiles: ProfileRepository {
    private var pending: [UUID: CheckedContinuation<Profile?, any Error>] = [:]
    func ownProfile(for userID: UUID) async throws -> Profile? {
        try await withCheckedThrowingContinuation { pending[userID] = $0 }
    }
    func contains(_ id: UUID) -> Bool { pending[id] != nil }
    func complete(_ id: UUID, result: Result<Profile?, any Error>) { pending.removeValue(forKey: id)?.resume(with: result) }
}

@MainActor
struct AppSessionTests {
    private func waitUntil(_ condition: () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            await Task.yield()
        }
        return false
    }

    @Test func signOutDiscardsLateProfile() async {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream), profiles: profiles)
        let observer = Task { await model.observe() }
        defer { observer.cancel(); events.finish() }
        let id = UUID()
        events.yield(.signedIn(userID: id))
        #expect(await waitUntil { await profiles.contains(id) })
        events.yield(.signedOut)
        #expect(await waitUntil { model.state == .signedOut })
        await profiles.complete(id, result: .success(Profile(id: id, handle: "stale")))
        for _ in 0..<20 { await Task.yield() }
        #expect(model.state == .signedOut)
    }

    @Test func accountSwitchDiscardsPreviousUser() async {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream), profiles: profiles)
        let observer = Task { await model.observe() }
        defer { observer.cancel(); events.finish() }
        let first = UUID(), second = UUID()
        events.yield(.signedIn(userID: first))
        #expect(await waitUntil { await profiles.contains(first) })
        events.yield(.signedIn(userID: second))
        #expect(await waitUntil { await profiles.contains(second) })
        let current = Profile(id: second, handle: "current")
        await profiles.complete(second, result: .success(current))
        #expect(await waitUntil { model.state == .signedIn(userID: second, profile: .loaded(current)) })
        await profiles.complete(first, result: .success(Profile(id: first)))
        for _ in 0..<20 { await Task.yield() }
        #expect(model.state == .signedIn(userID: second, profile: .loaded(current)))
    }

    @Test func missingFailureRetryAndTokenRefresh() async {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream), profiles: profiles)
        let observer = Task { await model.observe() }
        defer { observer.cancel(); events.finish() }
        let id = UUID()
        events.yield(.signedIn(userID: id))
        #expect(await waitUntil { await profiles.contains(id) })
        await profiles.complete(id, result: .success(nil))
        #expect(await waitUntil { model.state == .signedIn(userID: id, profile: .missing) })
        events.yield(.signedIn(userID: id)) // SDK token refresh must preserve the screen.
        for _ in 0..<20 { await Task.yield() }
        #expect(model.state == .signedIn(userID: id, profile: .missing))
        model.retryProfile()
        #expect(await waitUntil { await profiles.contains(id) })
        await profiles.complete(id, result: .failure(StubError.failed))
        #expect(await waitUntil { model.state == .signedIn(userID: id, profile: .failed) })
        model.retryProfile()
        #expect(await waitUntil { await profiles.contains(id) })
        let profile = Profile(id: id)
        await profiles.complete(id, result: .success(profile))
        #expect(await waitUntil { model.state == .signedIn(userID: id, profile: .loaded(profile)) })
    }

    @Test func rejectsWrongIdentityAndKeepsSignOutErrorSanitized() async {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream, failSignOut: true), profiles: profiles)
        let observer = Task { await model.observe() }
        defer { observer.cancel(); events.finish() }
        let id = UUID()
        events.yield(.signedIn(userID: id))
        #expect(await waitUntil { await profiles.contains(id) })
        await profiles.complete(id, result: .success(Profile(id: UUID())))
        #expect(await waitUntil { model.state == .signedIn(userID: id, profile: .failed) })
        await model.signOut()
        #expect(model.signOutFailed)
        #expect(!model.isSigningOut)
        #expect(model.state == .signedIn(userID: id, profile: .failed))
    }
}
