import Foundation

public enum AppEnvironment: String, Sendable {
    case local, staging, production
}

public enum ConfigurationError: Error, Equatable, LocalizedError {
    case missing(String), invalidEnvironment, invalidURL, unsafeEnvironment, invalidClientKey

    public var errorDescription: String? {
        switch self {
        case .missing(let field): "Missing configuration: \(field)."
        case .invalidEnvironment: "Choose a supported app environment."
        case .invalidURL: "The backend URL is invalid."
        case .unsafeEnvironment: "The backend URL does not match this environment."
        case .invalidClientKey: "Use a publishable client key or an anon key."
        }
    }
}

/// Public client configuration. Never accepts a service-role or secret key.
/// Validation checks key format, not authenticity; the server verifies credentials.
public struct AppConfiguration: Sendable, CustomDebugStringConvertible {
    public static let productionHost = "enosggckdxjiaqtxalhg.supabase.co"
    /// The only approved staging project (decision 38). Any other host is rejected, even another Supabase project.
    public static let stagingHost = "ankgfqkgflcalmlreetu.supabase.co"
    public let environment: AppEnvironment
    public let supabaseURL: URL
    public let publishableKey: String

    public init(environment: AppEnvironment, url: String, publishableKey: String) throws {
        guard !url.isEmpty, !url.contains("$(") else { throw ConfigurationError.missing("SupabaseURL") }
        guard let parts = URLComponents(string: url), let host = parts.host,
              parts.user == nil, parts.password == nil, parts.query == nil,
              parts.fragment == nil, parts.path.isEmpty || parts.path == "/",
              let parsed = parts.url else { throw ConfigurationError.invalidURL }
        let isLocal = ["localhost", "127.0.0.1"].contains(host)
        switch environment {
        case .local:
            guard isLocal, parts.scheme == "http", parts.port == 54321 else {
                throw ConfigurationError.unsafeEnvironment
            }
        case .staging:
            guard parts.scheme == "https", host == Self.stagingHost, parts.port == nil else {
                throw ConfigurationError.unsafeEnvironment
            }
        case .production:
            guard parts.scheme == "https", host == Self.productionHost, parts.port == nil else {
                throw ConfigurationError.unsafeEnvironment
            }
        }
        guard !publishableKey.isEmpty, !publishableKey.contains("$(") else {
            throw ConfigurationError.missing("SupabasePublishableKey")
        }
        guard Self.isPublicClientKey(publishableKey) else { throw ConfigurationError.invalidClientKey }
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
        let segments = key.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, !segments[2].isEmpty else { return false }
        var payload = String(segments[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return object["role"] as? String == "anon"
    }
}
