import Foundation

// Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
public enum BackendAllowlist {
    public static let stagingRef = "ankgfqkgflcalmlreetu"
    public static let stagingHost = "ankgfqkgflcalmlreetu.supabase.co"
    public static let deniedRefs = ["enosggckdxjiaqtxalhg"]

    public static func containsDeniedRef(_ value: String) -> Bool {
        deniedRefs.contains { value.lowercased().contains($0) }
    }

    public static func allowsRequest(_ url: URL, configuration: AppConfiguration) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return false }
        return !containsDeniedRef(url.absoluteString) && parts.user == nil && parts.password == nil
            && parts.fragment == nil && parts.scheme == configuration.supabaseURL.scheme
            && parts.host?.lowercased() == configuration.supabaseURL.host?.lowercased()
            && parts.port == configuration.supabaseURL.port
    }
}
