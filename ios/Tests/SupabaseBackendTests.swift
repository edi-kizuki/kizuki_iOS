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

/// All requests are intercepted, including unexpected endpoints. No network fallback.
private final class BackendURLProtocol: URLProtocol, @unchecked Sendable {
    static let route = TestRoute()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (body, code, offline) = Self.route.respond(to: request)
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

@Suite(.serialized)
struct SupabaseBackendTests {
    private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
    private let key = "sb_publishable_local_test_only"

    private func backend(withSession: Bool = true, expired: Bool = false, storage: MemoryAuthStorage = MemoryAuthStorage()) throws -> SupabaseBackend {
        let config = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        if withSession {
            // Synthetic credentials, valid only inside this intercepted test transport.
            let user = User(id: id, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                            createdAt: Date(), updatedAt: Date())
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
        return SupabaseBackend(configuration: config, storage: storage, session: URLSession(configuration: transport))
    }

    @Test func ownProfileUsesSDKAuthProjectionAndIdentityFilter() async throws {
        BackendURLProtocol.route.configure(body: "[{\"id\":\"\(id)\",\"handle\":\"creator\",\"display_handle\":\"Creator\",\"avatar_path\":null}]")
        let service = try backend()
        let profile = try await service.ownProfile(for: id)
        #expect(profile?.displayHandle == "Creator")
        let request = try #require(BackendURLProtocol.route.captured().last)
        #expect(request.url?.path == "/rest/v1/profiles")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "apikey") == key)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access-token")
        let query = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "id", value: "eq.\(id)")))
        #expect(query.contains(URLQueryItem(name: "select", value: "id,handle,display_handle,avatar_path")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "1")))
    }

    @Test func missingProfileIsDistinctFromServerFailure() async throws {
        BackendURLProtocol.route.configure(body: "[]")
        let service = try backend()
        #expect(try await service.ownProfile(for: id) == nil)
        BackendURLProtocol.route.configure(body: "{\"code\":\"42501\",\"message\":\"permission denied\"}", code: 403)
        await #expect(throws: (any Error).self) { try await service.ownProfile(for: id) }
    }

    @Test func refusesAnotherIdentityBeforeSendingRequest() async throws {
        BackendURLProtocol.route.configure(body: "[]")
        let service = try backend()
        await #expect(throws: (any Error).self) { try await service.ownProfile(for: UUID()) }
        #expect(BackendURLProtocol.route.captured().isEmpty)
    }

    @Test func missingSessionDoesNotReadProfile() async throws {
        BackendURLProtocol.route.configure(body: "[]")
        let service = try backend(withSession: false)
        await #expect(throws: (any Error).self) { try await service.ownProfile(for: id) }
        #expect(BackendURLProtocol.route.captured().isEmpty)
        var events = await service.events().makeAsyncIterator()
        #expect(await events.next() == .signedOut)
    }

    @Test func restoresValidSessionWithoutNetwork() async throws {
        BackendURLProtocol.route.configure(body: "[]")
        let service = try backend()
        var events = await service.events().makeAsyncIterator()
        #expect(await events.next() == .signedIn(userID: id))
        #expect(BackendURLProtocol.route.captured().isEmpty)
    }

    @Test func expiredSessionNeverBecomesSignedIn() async throws {
        BackendURLProtocol.route.configure(body: "{\"error_code\":\"refresh_token_not_found\",\"msg\":\"Invalid refresh token\"}", code: 400)
        let service = try backend(expired: true)
        var events = await service.events().makeAsyncIterator()
        let initial = await events.next()
        #expect(initial == .unavailable || initial == .signedOut)
    }

    @Test(arguments: [200, 401]) func localSignOutClearsStorageAndUsesLocalScope(_ code: Int) async throws {
        BackendURLProtocol.route.configure(body: code == 200 ? "{}" : "{\"msg\":\"expired\"}", code: code)
        let storage = MemoryAuthStorage()
        let service = try backend(storage: storage)
        try await service.signOut()
        let config = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        #expect(try storage.retrieve(key: config.sessionStorageKey) == nil)
        // A refresh request from the previous test's session can land after configure(); pick the logout call itself.
        let request = try #require(BackendURLProtocol.route.captured().last { $0.url?.path == "/auth/v1/logout" })
        #expect(request.url?.path == "/auth/v1/logout")
        #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?
            .contains(URLQueryItem(name: "scope", value: "local")) == true)
    }

    @Test func offlineSignOutStillClearsLocalSession() async throws {
        BackendURLProtocol.route.configure(body: "{}", offline: true)
        let storage = MemoryAuthStorage()
        let service = try backend(storage: storage)
        try await service.signOut()
        let config = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        #expect(try storage.retrieve(key: config.sessionStorageKey) == nil)
    }

    @Test func expiredSessionRefreshesThroughSDK() async throws {
        let user = User(id: id, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                        createdAt: Date(), updatedAt: Date())
        let refreshed = Session(accessToken: "refreshed-test-token", tokenType: "bearer", expiresIn: 3600,
                                expiresAt: Date().timeIntervalSince1970 + 3600,
                                refreshToken: "rotated-test-refresh-token", user: user)
        let encoded = try AuthClient.Configuration.jsonEncoder.encode(refreshed)
        BackendURLProtocol.route.configure(body: String(decoding: encoded, as: UTF8.self))
        let service = try backend(expired: true)
        var events = await service.events().makeAsyncIterator()
        var restored = false
        for _ in 0..<2 {
            if await events.next() == .signedIn(userID: id) { restored = true; break }
        }
        #expect(restored)
        #expect(BackendURLProtocol.route.captured().contains { $0.url?.path == "/auth/v1/token" })
    }
}
