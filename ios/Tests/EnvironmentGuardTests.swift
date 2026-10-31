// Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
import Foundation
import KizukiCore
@testable import KizukiInfrastructure
import Supabase
import Testing

private final class ProbeStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var accesses = 0
    var count: Int { lock.withLock { accesses } }
    func store(key: String, value: Data) throws { lock.withLock { accesses += 1 } }
    func retrieve(key: String) throws -> Data? { lock.withLock { accesses += 1 }; return nil }
    func remove(key: String) throws { lock.withLock { accesses += 1 } }
}

private final class ProbeRoute: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    let body: String
    let code: Int
    let responseURL: URL?
    let failure: URLError.Code?
    init(_ body: String, code: Int = 200, responseURL: URL? = nil, failure: URLError.Code? = nil) {
        self.body = body; self.code = code; self.responseURL = responseURL; self.failure = failure
    }
    func record(_ request: URLRequest) { lock.withLock { requests.append(request) } }
    var captured: [URLRequest] { lock.withLock { requests } }
}

private final class ProbeProtocol: URLProtocol, @unchecked Sendable {
    static let header = "X-B03-Test"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: ProbeRoute] = [:]
    static func set(_ id: String, _ route: ProbeRoute?) { lock.withLock { routes[id] = route } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.header), let route = Self.lock.withLock({ Self.routes[id] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled)); return
        }
        route.record(request)
        if let failure = route.failure { client?.urlProtocol(self, didFailWithError: URLError(failure)); return }
        guard let url = route.responseURL ?? request.url,
              let response = HTTPURLResponse(url: url, statusCode: route.code, httpVersion: nil,
                  headerFields: route.code == 302 ? ["Location": "https://" + BackendAllowlist.stagingHost + "/next"] : nil)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(route.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class ProbeHarness {
    let id = UUID().uuidString
    let route: ProbeRoute
    let session: URLSession
    init(_ body: String, code: Int = 200, responseURL: URL? = nil, failure: URLError.Code? = nil) {
        route = ProbeRoute(body, code: code, responseURL: responseURL, failure: failure)
        ProbeProtocol.set(id, route)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProbeProtocol.self]
        config.httpAdditionalHeaders = [ProbeProtocol.header: id]
        session = URLSession(configuration: config)
    }
    deinit { session.invalidateAndCancel(); ProbeProtocol.set(id, nil) }
}

struct EnvironmentGuardTests {
    private let base = "https://" + BackendAllowlist.stagingHost
    private let key = "sb_publishable_synthetic_guard_tests"
    private var good: String { "{\"environment\":\"staging\",\"project_ref\":\"\(BackendAllowlist.stagingRef)\"}" }
    private func config() throws -> AppConfiguration { try AppConfiguration(environment: .staging, url: base, publishableKey: key) }

    @Test func A1_A2_productionAlwaysFailsBeforeURLOrKey() {
        for url in ["", "not a URL", base, "https://" + BackendAllowlist.deniedRefs[0] + ".supabase.co"] {
            for value in [key, "", "sb_secret_no"] {
                #expect(throws: ConfigurationError.productionDisabled) {
                    try AppConfiguration(environment: .production, url: url, publishableKey: value)
                }
            }
        }
    }

    @Test func A3_unapprovedURLMatrix() {
        let urls = ["https://unapproved-review-probe.supabase.co", base + ".evil.test", base + ".", base + ":443", base + "/path",
                    base + "?x=1", base + "#fragment", base.replacingOccurrences(of: "https:", with: "http:"),
                    base + "@" + BackendAllowlist.deniedRefs[0] + ".supabase.co", "https://ANKGFQKGFLCALMLREETU.supabase.co.evil",
                    "https://аnkgfqkgflcalmlreetu.supabase.co", base + "/" + BackendAllowlist.deniedRefs[0]]
        for url in urls {
            #expect(throws: (any Error).self) { try AppConfiguration(environment: .staging, url: url, publishableKey: key) }
        }
    }

    @Test func A4_A5_A6_configurationAndJWTBindings() throws {
        let approved = try config()
        #expect(approved.sessionStorageKey == "kizuki.staging.\(base).auth")
        func jwt(_ role: String, _ ref: String) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: ["role": role, "ref": ref])
            return "header." + data.base64EncodedString().replacingOccurrences(of: "=", with: "") + ".signature"
        }
        _ = try AppConfiguration(environment: .staging, url: base, publishableKey: jwt("anon", BackendAllowlist.stagingRef))
        #expect(throws: ConfigurationError.backendDenied) {
            try AppConfiguration(environment: .staging, url: base, publishableKey: jwt("anon", BackendAllowlist.deniedRefs[0]))
        }
        #expect(throws: ConfigurationError.invalidClientKey) {
            try AppConfiguration(environment: .staging, url: base, publishableKey: jwt("service_role", BackendAllowlist.stagingRef))
        }
        #expect(throws: ConfigurationError.invalidClientKey) { try AppConfiguration(environment: .staging, url: base, publishableKey: "sb_secret_synthetic") }
        #expect(throws: (any Error).self) { try AppConfiguration(environment: .local, url: base, publishableKey: key) }
        _ = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
    }

    @Test func A7_badRequestNeverReachesUnderlyingTransport() async throws {
        let harness = ProbeHarness(good)
        let transport = GuardedTransport(configuration: try config(), session: harness.session)
        for url in ["https://unapproved-review-probe.supabase.co", base + "/" + BackendAllowlist.deniedRefs[0],
                    base + "?ref=" + BackendAllowlist.deniedRefs[0], "http://127.0.0.1:54321", base + ":443/test"] {
            await #expect(throws: (any Error).self) { _ = try await transport.session.data(from: URL(string: url)!) }
        }
        #expect(harness.route.captured.isEmpty)
    }

    @Test func A8_redirectsAreCancelledIncludingSameHost() async throws {
        let harness = ProbeHarness("", code: 302)
        let transport = GuardedTransport(configuration: try config(), session: harness.session)
        await #expect(throws: (any Error).self) { try await transport.probe() }
        #expect(harness.route.captured.count == 1)
        // Exercise the delegate callback separately: custom URLProtocol redirects are unsupported by Foundation.
        let delegate = RefuseRedirects()
        let url = URL(string: base)!
        let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)!
        for destination in [base + "/next", "https://" + BackendAllowlist.deniedRefs[0] + ".supabase.co"] {
            await withCheckedContinuation { continuation in
                delegate.urlSession(harness.session, task: harness.session.dataTask(with: url), willPerformHTTPRedirection: response,
                                    newRequest: URLRequest(url: URL(string: destination)!)) { request in
                    #expect(request == nil); continuation.resume()
                }
            }
        }
        #expect(harness.route.captured.count == 1)
    }

    @Test func A9_mismatchedResponseURLIsRejected() async throws {
        let harness = ProbeHarness(good, responseURL: URL(string: "https://other.supabase.co"))
        let transport = GuardedTransport(configuration: try config(), session: harness.session)
        await #expect(throws: ConfigurationError.backendRefused) { try await transport.probe() }
    }

    @Test func A10_probeFailuresNeverConstructAuthOrTouchStorage() async throws {
        let cases: [(String, Int, URLError.Code?)] = [
            ("{\"environment\":\"production\"}", 200, nil),
            ("{\"environment\":\"staging\",\"project_ref\":\"other\"}", 200, nil),
            ("{\"environment\":\"unmarked\"}", 200, nil), (good, 404, nil), ("garbage", 200, nil),
            (good, 200, .timedOut), (good, 200, .notConnectedToInternet), ("[]", 200, nil)]
        for (body, code, failure) in cases {
            let harness = ProbeHarness(body, code: code, failure: failure)
            let storage = ProbeStorage()
            let backend = SupabaseBackend(configuration: try config(), storage: storage, session: harness.session)
            await #expect(throws: ConfigurationError.backendRefused) { try await backend.prepare() }
            await #expect(throws: ConfigurationError.backendRefused) { try await backend.signIn(email: "synthetic@test.invalid", password: "synthetic") }
            #expect(storage.count == 0)
            #expect(harness.route.captured.count == 2) // Failure is never cached; retries only probe.
            #expect(harness.route.captured.allSatisfy { $0.url?.path == "/rest/v1/rpc/kizuki_environment" })
            #expect(harness.route.captured.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
        }
    }

    @Test func A10_successIsCachedForThisBackendAndConcurrentCallsShareProbe() async throws {
        let harness = ProbeHarness(good)
        let backend = SupabaseBackend(configuration: try config(), storage: ProbeStorage(), session: harness.session)
        defer { backend.stopBackgroundRefresh() }
        async let first: Void = backend.prepare()
        async let second: Void = backend.prepare()
        _ = try await (first, second)
        try await backend.prepare()
        #expect(harness.route.captured.count == 1)
        #expect(harness.route.captured.first?.value(forHTTPHeaderField: "apikey") == key)
    }

    @Test func A11_realtimeConstructionUsesValidatedOrigin() throws {
        let configuration = try config()
        var components = URLComponents(url: configuration.supabaseURL.appendingPathComponent("realtime/v1"), resolvingAgainstBaseURL: false)!
        components.scheme = "wss"
        #expect(components.host == BackendAllowlist.stagingHost)
        #expect(components.port == nil)
        // SDK 2.55.4 passes global.session to RealtimeV2; URLProtocol interception of WebSockets
        // is not guaranteed. No realtime consumer exists. The compiled origin pin is the guarantee.
    }
}
