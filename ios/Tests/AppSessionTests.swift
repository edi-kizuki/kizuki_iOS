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
    @Test func rootPhasesFollowServerEvidenceAndExplicitRefresh() async throws {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream), profiles: profiles)
        let observer = Task { await model.observe() }
        defer { observer.cancel(); events.finish() }
        #expect(model.phase == .restoring)
        events.yield(.signedOut)
        #expect(await waitUntil { model.phase == .entry })
        let id = UUID()
        events.yield(.verificationRequired(userID: id))
        #expect(await waitUntil { (await profiles.contains(id)) && model.phase == .verifyEmail })
        await profiles.complete(id, result: .success(Profile(id: id)))
        #expect(await waitUntil { model.state == .signedIn(userID: id, profile: .loaded(Profile(id: id))) })
        events.yield(.userUpdated(userID: id, emailVerified: true))
        #expect(await waitUntil { await profiles.contains(id) })
        await profiles.complete(id, result: .success(Profile(id: id)))
        #expect(await waitUntil { model.phase == .eligibility })
        let scope = try #require(model.scope)
        model.refreshProfile()
        #expect(await waitUntil { await profiles.contains(id) })
        await profiles.complete(id, result: .success(Profile(id: id, eligibleAt: .distantPast, onboardingStep: 4)))
        #expect(await waitUntil { model.phase == .onboarding(step: 4) })
        model.refreshProfile()
        #expect(await waitUntil { await profiles.contains(id) })
        let ready = Profile(id: id, onboardingCompletedAt: .distantPast, eligibleAt: .distantPast)
        await profiles.complete(id, result: .success(ready))
        #expect(await waitUntil { model.phase == .main })
        #expect(model.scope === scope)
        events.yield(.passwordRecovery(userID: id))
        #expect(await waitUntil { model.phase == .passwordRecovery })
        events.yield(.signedIn(userID: id)) // Refreshed tokens cannot bypass recovery.
        for _ in 0..<20 { await Task.yield() }
        #expect(model.phase == .passwordRecovery)
        model.finishPasswordRecovery()
        #expect(await waitUntil { await profiles.contains(id) })
        await profiles.complete(id, result: .success(ready))
        #expect(await waitUntil { model.phase == .main })
        for status in [AccountStatus.deleting, .deleted, .suspended] {
            model.refreshProfile()
            #expect(await waitUntil { await profiles.contains(id) })
            await profiles.complete(id, result: .success(Profile(id: id, accountStatus: status)))
            #expect(await waitUntil { model.phase == .deleted })
        }
        events.yield(.unavailable)
        #expect(await waitUntil { model.phase == .unavailable })
        #expect(scope.isCancelled)
    }

    @Test func signOutAndAccountSwitchCancelTasksChannelsAndCaches() async throws {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream), profiles: profiles)
        let observer = Task { await model.observe() }
        defer { observer.cancel(); events.finish() }
        let first = UUID(), second = UUID()
        events.yield(.signedIn(userID: first))
        #expect(await waitUntil { await profiles.contains(first) })
        await profiles.complete(first, result: .success(Profile(id: first)))
        let firstScope = try #require(model.scope)
        let probe = ScopeProbe()
        firstScope.run {
            await probe.start()
            do { try await Task.sleep(for: .seconds(60)) } catch {}
            await probe.stop()
        }
        firstScope.onCancel { await probe.removeChannel() }
        firstScope.onCancel { await probe.purgeCache() }
        #expect(await waitUntil { await probe.started })
        events.yield(.signedIn(userID: second))
        #expect(await waitUntil { await profiles.contains(second) })
        #expect(firstScope.isCancelled)
        #expect(await waitUntil { await probe.stopped })
        #expect(await probe.channelsRemoved == 1)
        #expect(await probe.cachesPurged == 1)
        await firstScope.cancel()
        #expect(await probe.channelsRemoved == 1) // Idempotent.
        #expect(model.scope?.userID == second)
        let secondScope = try #require(model.scope)
        secondScope.onCancel { await probe.removeChannel() }
        await profiles.complete(second, result: .success(Profile(id: second)))
        #expect(await waitUntil { model.state == .signedIn(userID: second, profile: .loaded(Profile(id: second))) })
        await model.signOut()
        #expect(model.phase == .entry)
        #expect(secondScope.isCancelled)
        #expect(await probe.channelsRemoved == 2)
        #expect(model.scope == nil)
    }

    @Test func observerCancellationAndViewRemovalCleanUpOnce() async throws {
        let (stream, events) = AsyncStream<SessionEvent>.makeStream()
        let profiles = DeferredProfiles()
        let model = AppSession(sessions: SessionStub(stream: stream), profiles: profiles)
        let observer = Task { await model.observe() }
        let id = UUID()
        events.yield(.signedIn(userID: id))
        #expect(await waitUntil { await profiles.contains(id) })
        let scope = try #require(model.scope)
        let probe = ScopeProbe()
        let channel = scope.onCancel { await probe.removeChannel() }
        await scope.remove(channel) // Same hook used by channel AsyncStream.onTermination.
        observer.cancel()
        await observer.value
        #expect(scope.isCancelled)
        #expect(await probe.channelsRemoved == 1)
        #expect(model.scope == nil)
        #expect(model.phase == .restoring)
        await profiles.complete(id, result: .success(Profile(id: id)))
        events.finish()
    }

}

private actor ScopeProbe {
    private(set) var started = false
    private(set) var stopped = false
    private(set) var channelsRemoved = 0
    private(set) var cachesPurged = 0
    func start() { started = true }
    func stop() { stopped = true }
    func removeChannel() { channelsRemoved += 1 }
    func purgeCache() { cachesPurged += 1 }
}
