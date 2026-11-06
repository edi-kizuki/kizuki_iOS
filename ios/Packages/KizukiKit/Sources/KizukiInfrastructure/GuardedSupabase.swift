import Foundation
import KizukiCore
import Supabase

// Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
/// Owns the HTTP firewall. The SDK is not constructed until the marker probe succeeds.
public final class GuardedTransport: @unchecked Sendable {
    public let session: URLSession
    private let identifier: String
    private let configuration: AppConfiguration

    public init(configuration: AppConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        identifier = UUID().uuidString
        let innerConfig = session.configuration
        innerConfig.connectionProxyDictionary = [:]
        innerConfig.urlCache = nil
        innerConfig.httpCookieStorage = nil
        let inner = URLSession(configuration: innerConfig, delegate: RefuseRedirects(), delegateQueue: nil)
        GuardProtocol.register(identifier, policy: .init(configuration: configuration, session: inner))
        let outer = URLSessionConfiguration.ephemeral
        outer.protocolClasses = [GuardProtocol.self]
        outer.httpAdditionalHeaders = [GuardProtocol.header: identifier]
        outer.connectionProxyDictionary = [:]
        self.session = URLSession(configuration: outer, delegate: RefuseRedirects(), delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
        GuardProtocol.remove(identifier)
    }

    public func probe() async throws {
        var request = URLRequest(url: configuration.supabaseURL.appendingPathComponent("rest/v1/rpc/kizuki_environment"))
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let marker = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  marker["environment"] as? String == configuration.environment.rawValue,
                  Set(marker.keys) == ["environment", "project_ref"],
                  configuration.environment == .local
                    ? marker["project_ref"] is NSNull
                    : marker["project_ref"] as? String == BackendAllowlist.stagingRef
            else { throw ConfigurationError.backendRefused }
        } catch {
            throw ConfigurationError.backendRefused
        }
    }
}

final class RefuseRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private final class GuardProtocol: URLProtocol, @unchecked Sendable {
    struct Policy: Sendable { let configuration: AppConfiguration; let session: URLSession }
    static let header = "X-Kizuki-Transport"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var policies: [String: Policy] = [:]
    private let taskLock = NSLock()
    private var work: Task<Void, Never>?
    static func register(_ id: String, policy: Policy) { lock.withLock { policies[id] = policy } }
    static func remove(_ id: String) { lock.withLock { policies.removeValue(forKey: id) }?.session.invalidateAndCancel() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.header),
              let policy = Self.lock.withLock({ Self.policies[id] }), let url = request.url,
              BackendAllowlist.allowsRequest(url, configuration: policy.configuration) else {
            client?.urlProtocol(self, didFailWithError: ConfigurationError.backendDenied); return
        }
        var forwarded = request
        forwarded.setValue(nil, forHTTPHeaderField: Self.header)
        let safeRequest = forwarded
        taskLock.withLock {
            work = Task { @Sendable [self, policy, safeRequest] in
                do {
                    let (data, response) = try await policy.session.data(for: safeRequest)
                    guard let responseURL = response.url,
                          BackendAllowlist.allowsRequest(responseURL, configuration: policy.configuration),
                          let http = response as? HTTPURLResponse, !(300..<400).contains(http.statusCode)
                    else { throw ConfigurationError.backendDenied }
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: data)
                    client?.urlProtocolDidFinishLoading(self)
                } catch { client?.urlProtocol(self, didFailWithError: error) }
            }
        }
    }
    override func stopLoading() { taskLock.withLock { work?.cancel(); work = nil } }
}

/// Internal factory: the only caller is the actor after a successful probe.
enum GuardedSupabase {
    static func makeClient(_ configuration: AppConfiguration, storage: any AuthLocalStorage, transport: GuardedTransport) -> SupabaseClient {
        SupabaseClient(supabaseURL: configuration.supabaseURL, supabaseKey: configuration.publishableKey,
                       options: .init(auth: .init(storage: storage, storageKey: configuration.sessionStorageKey,
                                                flowType: .pkce, autoRefreshToken: true,
                                                emitLocalSessionAsInitialSession: true),
                                      global: .init(session: transport.session, logger: nil)))
    }
}

actor ProbedClient {
    private let configuration: AppConfiguration
    private let storage: @Sendable () -> any AuthLocalStorage
    let transport: GuardedTransport
    private var pending: Task<SupabaseClient, Error>?
    private var ready: SupabaseClient?

    init(configuration: AppConfiguration, storage: @escaping @Sendable () -> any AuthLocalStorage, transport: GuardedTransport) {
        self.configuration = configuration; self.storage = storage; self.transport = transport
    }
    func client() async throws -> SupabaseClient {
        if let ready { return ready }
        if let pending { return try await pending.value }
        let task = Task { [configuration, storage, transport] in
            try await transport.probe()
            return GuardedSupabase.makeClient(configuration, storage: storage(), transport: transport)
        }
        pending = task
        do {
            let result = try await task.value
            ready = result; pending = nil
            return result
        } catch {
            pending = nil
            print("backend_refused code=E_MARKER_WRONG")
            throw ConfigurationError.backendRefused
        }
    }
    func stop() async { await ready?.auth.stopAutoRefresh() }
}
