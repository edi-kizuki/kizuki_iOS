import Foundation
import KizukiCore
import KizukiInfrastructure
import Supabase
import Testing

private final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { lock.withLock { values[key] = nil } }
}

private final class TestRoute: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    private var responseBody = Data("[]".utf8)
    private var responseCode = 200
    private var networkFailure = false
    func configure(body: String, code: Int = 200, offline: Bool = false) {
        lock.withLock { requests = []; responseBody = Data(body.utf8); responseCode = code; networkFailure = offline }
    }
    func respond(to request: URLRequest) -> (Data, Int, Bool) {
        lock.withLock { requests.append(request); return (responseBody, responseCode, networkFailure) }
    }
    func captured() -> [URLRequest] { lock.withLock { requests } }
}

/// Each test owns one route, keyed by a request header its own transport adds. A late request from an earlier test's
/// client therefore reaches that test's route (or none), never the next test's response slot or capture list.
private enum Routes {
    static let header = "X-Kizuki-Test-Route"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: TestRoute] = [:]
    static func register(_ id: String, _ route: TestRoute) { lock.withLock { routes[id] = route } }
    static func unregister(_ id: String) { lock.withLock { routes[id] = nil } }
    static func route(for request: URLRequest) -> TestRoute? {
        guard let id = request.value(forHTTPHeaderField: header) else { return nil }
        return lock.withLock { routes[id] }
    }
}

/// All requests are intercepted, including unexpected endpoints. No network fallback.
private final class BackendURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let route = Routes.route(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled)); return
        }
        let (body, code, offline) = route.respond(to: request)
        if offline {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return
        }
        guard let url = request.url, url.host == "127.0.0.1", url.port == 54321,
              let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// One isolated transport per test. `stop()` ends SDK refresh work before the test returns.
private final class Harness: @unchecked Sendable {
    let route = TestRoute()
    let routeID = UUID().uuidString
    private let lock = NSLock()
    private var backends: [SupabaseBackend] = []
    init() { Routes.register(routeID, route) }
    func track(_ backend: SupabaseBackend) -> SupabaseBackend { lock.withLock { backends.append(backend) }; return backend }
    func stop() {
        lock.withLock { backends }.forEach { $0.stopBackgroundRefresh() }
        Routes.unregister(routeID)
    }
}

/// Reads events with a deadline. A missing event fails the test instead of hanging it.
private func collect(_ stream: AsyncStream<SessionEvent>, limit: Int = 3, timeout: Duration = .seconds(10),
                     until stop: @escaping @Sendable (SessionEvent) -> Bool = { _ in true }) async -> [SessionEvent] {
    await withTaskGroup(of: [SessionEvent]?.self) { group in
        group.addTask {
            var seen: [SessionEvent] = []
            for await event in stream { seen.append(event); if stop(event) || seen.count >= limit { break } }
            return seen
        }
        group.addTask { try? await Task.sleep(for: timeout); return nil }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first ?? []
    }
}

@Suite(.serialized)
struct SupabaseBackendTests {
    private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
    private let key = "sb_publishable_local_test_only"

    private func backend(_ harness: Harness, withSession: Bool = true, expired: Bool = false, storage: MemoryAuthStorage = MemoryAuthStorage()) throws -> SupabaseBackend {
        let config = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        if withSession {
            // Synthetic credentials, valid only inside this intercepted test transport.
            let user = User(id: id, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                            createdAt: Date(), emailConfirmedAt: Date(), updatedAt: Date())
            let session = Session(accessToken: "test-access-token", tokenType: "bearer", expiresIn: 3600,
                                  expiresAt: Date().timeIntervalSince1970 + (expired ? -3600 : 3600),
                                  refreshToken: "test-refresh-token", user: user)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            try storage.store(key: config.sessionStorageKey, value: encoder.encode(session))
        }
        let transport = URLSessionConfiguration.ephemeral
        transport.protocolClasses = [BackendURLProtocol.self]
        transport.httpAdditionalHeaders = [Routes.header: harness.routeID]
        return harness.track(SupabaseBackend(configuration: config, storage: storage, session: URLSession(configuration: transport)))
    }

    @Test func ownProfileUsesSDKAuthProjectionAndIdentityFilter() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "[{\"id\":\"\(id)\",\"handle\":\"creator\",\"display_handle\":\"Creator\",\"avatar_path\":null}]")
        let service = try backend(harness)
        let profile = try await service.ownProfile(for: id)
        #expect(profile?.displayHandle == "Creator")
        #expect(profile?.eligibleAt == nil)
        #expect(profile?.onboardingCompletedAt == nil)
        let request = try #require(harness.route.captured().last { $0.url?.path == "/rest/v1/profiles" })
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "apikey") == key)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access-token")
        let query = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "id", value: "eq.\(id)")))
        #expect(query.contains(URLQueryItem(name: "select", value: "id,handle,display_handle,avatar_path")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "1")))
    }

    @Test func missingProfileIsDistinctFromServerFailure() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "[]")
        let service = try backend(harness)
        #expect(try await service.ownProfile(for: id) == nil)
        harness.route.configure(body: "{\"code\":\"42501\",\"message\":\"permission denied\"}", code: 403)
        await #expect(throws: (any Error).self) { try await service.ownProfile(for: id) }
    }

    @Test func refusesAnotherIdentityBeforeSendingRequest() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "[]")
        let service = try backend(harness)
        await #expect(throws: (any Error).self) { try await service.ownProfile(for: UUID()) }
        let profileReads = harness.route.captured().filter { $0.url?.path == "/rest/v1/profiles" }
        #expect(profileReads.isEmpty)
    }

    @Test func missingSessionDoesNotReadProfile() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "[]")
        let service = try backend(harness, withSession: false)
        await #expect(throws: (any Error).self) { try await service.ownProfile(for: id) }
        #expect(harness.route.captured().isEmpty)
        #expect(await collect(await service.events(), limit: 1) == [.signedOut])
    }

    @Test func restoresValidSessionWithoutNetwork() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "[]")
        let service = try backend(harness)
        #expect(await collect(await service.events(), limit: 1) == [.signedIn(userID: id)])
        #expect(harness.route.captured().isEmpty)
    }

    @Test func expiredSessionNeverBecomesSignedIn() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "{\"error_code\":\"refresh_token_not_found\",\"msg\":\"Invalid refresh token\"}", code: 400)
        let service = try backend(harness, expired: true)
        let initial = await collect(await service.events(), limit: 1)
        #expect(initial == [.unavailable] || initial == [.signedOut])
    }

    @Test(arguments: [200, 401]) func localSignOutClearsStorageAndUsesLocalScope(_ code: Int) async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: code == 200 ? "{}" : "{\"msg\":\"expired\"}", code: code)
        let storage = MemoryAuthStorage()
        let service = try backend(harness, storage: storage)
        try await service.signOut()
        let config = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        #expect(try storage.retrieve(key: config.sessionStorageKey) == nil)
        let request = try #require(harness.route.captured().last { $0.url?.path == "/auth/v1/logout" })
        #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?
            .contains(URLQueryItem(name: "scope", value: "local")) == true)
    }

    @Test func offlineSignOutStillClearsLocalSession() async throws {
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: "{}", offline: true)
        let storage = MemoryAuthStorage()
        let service = try backend(harness, storage: storage)
        try await service.signOut()
        let config = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        #expect(try storage.retrieve(key: config.sessionStorageKey) == nil)
    }

    @Test func replayCommittedContracts() async throws {
        let directory = try #require(Bundle(for: ContractBundleMarker.self).resourceURL).appendingPathComponent("Contracts")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            let recording = try JSONDecoder().decode(RepositoryContract.self, from: Data(contentsOf: file))
            try await replay(recording)
        }
        // B01 permits an empty set. Directory absence is a failure, never a silently skipped replay.
    }

    @Test func replayHarnessExercisesSuccessAndFailure() async throws {
        let body = "[{\"id\":\"\(id)\",\"handle\":\"creator\"}]"
        let success = RepositoryContract(version: 1, operation: "profile.own", userID: id,
            request: .init(method: "GET", path: "/rest/v1/profiles", query: ["id": "eq.\(id)", "limit": "1",
                "select": "id,handle,display_handle,avatar_path"]),
            response: .init(status: 200, body: body),
            expected: .init(profile: Profile(id: id, handle: "creator"), fails: false))
        try await replay(success)
        let failure = RepositoryContract(version: 1, operation: success.operation, userID: id, request: success.request,
            response: .init(status: 403, body: "{\"code\":\"42501\",\"message\":\"permission denied\"}"),
            expected: .init(profile: nil, fails: true))
        try await replay(failure)
    }

    private func replay(_ recording: RepositoryContract) async throws {
        #expect(recording.version == 1)
        guard recording.version == 1, recording.operation == "profile.own", recording.userID == id else {
            Issue.record("Unsupported repository contract version, operation or test identity")
            return
        }
        let harness = Harness(); defer { harness.stop() }
        harness.route.configure(body: recording.response.body, code: recording.response.status)
        let service = try backend(harness)
        if recording.expected.fails {
            await #expect(throws: (any Error).self) { try await service.ownProfile(for: recording.userID) }
        } else {
            #expect(try await service.ownProfile(for: recording.userID) == recording.expected.profile)
        }
        let request = try #require(harness.route.captured().last { $0.url?.path == "/rest/v1/profiles" })
        #expect(request.httpMethod == recording.request.method)
        #expect(request.url?.path == recording.request.path)
        let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") }) == recording.request.query)
    }

    @Test func expiredSessionRefreshesThroughSDK() async throws {
        let harness = Harness(); defer { harness.stop() }
        let user = User(id: id, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                        createdAt: Date(), emailConfirmedAt: Date(), updatedAt: Date())
        let refreshed = Session(accessToken: "refreshed-test-token", tokenType: "bearer", expiresIn: 3600,
                                expiresAt: Date().timeIntervalSince1970 + 3600,
                                refreshToken: "rotated-test-refresh-token", user: user)
        let encoded = try AuthClient.Configuration.jsonEncoder.encode(refreshed)
        harness.route.configure(body: String(decoding: encoded, as: UTF8.self))
        let service = try backend(harness, expired: true)
        // Bounded wait: the refreshed session must arrive within the deadline or the test fails.
        let seen = await collect(await service.events(), limit: 3, until: { [expected = id] in $0 == .signedIn(userID: expected) })
        #expect(seen.contains(.signedIn(userID: id)))
        let refreshes = harness.route.captured().filter { $0.url?.path == "/auth/v1/token" }
        #expect(!refreshes.isEmpty)
    }
}
