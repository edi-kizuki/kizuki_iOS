import Foundation

public enum AppEnvironment: String, Sendable {
    case local, staging, production
}

public enum ConfigurationError: Error, Equatable, LocalizedError {
    case missing(String), invalidEnvironment, invalidURL, unsafeEnvironment, invalidClientKey
    case productionDisabled, backendDenied, backendRefused

    public var errorDescription: String? {
        switch self {
        case .missing(let field): "Missing configuration: \(field)."
        case .invalidEnvironment: "Choose a supported app environment."
        case .invalidURL: "The backend URL is invalid."
        case .unsafeEnvironment: "The backend URL does not match this environment."
        case .productionDisabled: "Production is disabled in this build."
        case .backendDenied, .backendRefused: "This build can’t connect to its server."
        case .invalidClientKey: "Use a publishable client key or an anon key."
        }
    }
}

/// Public client configuration. Never accepts a service-role or secret key.
/// Validation checks key format, not authenticity; the server verifies credentials.
public struct AppConfiguration: Sendable, CustomDebugStringConvertible {
    public static let stagingHost = BackendAllowlist.stagingHost
    public let environment: AppEnvironment
    public let supabaseURL: URL
    public let publishableKey: String

    public init(environment: AppEnvironment, url: String, publishableKey: String) throws {
        guard environment != .production else { throw ConfigurationError.productionDisabled }
        guard !BackendAllowlist.containsDeniedRef(url) else { throw ConfigurationError.backendDenied }
        guard !url.isEmpty, !url.contains("$(") else { throw ConfigurationError.missing("SupabaseURL") }
        guard let parts = URLComponents(string: url), let host = parts.host,
              parts.user == nil, parts.password == nil, parts.query == nil,
              parts.fragment == nil, parts.path.isEmpty || parts.path == "/",
              let parsed = parts.url else { throw ConfigurationError.invalidURL }
        let isLocal = ["localhost", "127.0.0.1"].contains(host)
        switch environment {
        case .local:
            #if !DEBUG
            throw ConfigurationError.unsafeEnvironment
            #else
            guard isLocal, parts.scheme == "http", parts.port == 54321 else {
                throw ConfigurationError.unsafeEnvironment
            }
            #endif
        case .staging:
            guard parts.scheme == "https", host.lowercased() == Self.stagingHost, parts.port == nil else {
                throw ConfigurationError.backendDenied
            }
        case .production:
            throw ConfigurationError.productionDisabled
        }
        guard !publishableKey.isEmpty, !publishableKey.contains("$(") else {
            throw ConfigurationError.missing("SupabasePublishableKey")
        }
        guard Self.isPublicClientKey(publishableKey) else { throw ConfigurationError.invalidClientKey }
        if environment == .staging, let ref = Self.jwtPayload(publishableKey)?["ref"] {
            guard ref as? String == BackendAllowlist.stagingRef else { throw ConfigurationError.backendDenied }
        }
        self.environment = environment
        self.supabaseURL = parsed
        self.publishableKey = publishableKey
    }

    public init(values: [String: String]) throws {
        guard let environment = values["KizukiEnvironment"],
              let parsed = AppEnvironment(rawValue: environment) else { throw ConfigurationError.invalidEnvironment }
        try self.init(environment: parsed, url: values["SupabaseURL"] ?? "",
                      publishableKey: values["SupabasePublishableKey"] ?? "")
    }

    /// Separate Keychain namespaces for each environment and URL (including port).
    public var sessionStorageKey: String { "kizuki.\(environment.rawValue).\(supabaseURL.absoluteString).auth" }
    public var debugDescription: String { "AppConfiguration(\(environment.rawValue), key: <redacted>)" }

    private static func isPublicClientKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_publishable_") {
            let suffix = key.dropFirst("sb_publishable_".count)
            return suffix.count >= 8 && suffix.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
        }
        return jwtPayload(key)?["role"] as? String == "anon"
    }

    private static func jwtPayload(_ key: String) -> [String: Any]? {
        let segments = key.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, !segments[2].isEmpty else { return nil }
        var payload = String(segments[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }
}
