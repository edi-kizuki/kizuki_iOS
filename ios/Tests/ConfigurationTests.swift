import Foundation
import KizukiCore
import Testing

struct ConfigurationTests {
    private let key = "sb_publishable_local_test_only"

    @Test func acceptsLocalAndSeparatesStorage() throws {
        let local = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        let staging = try AppConfiguration(environment: .staging,
                                              url: "https://ankgfqkgflcalmlreetu.supabase.co", publishableKey: key)
        #expect(local.sessionStorageKey != staging.sessionStorageKey)
        #expect(!String(reflecting: local).contains(key))
    }

    @Test(arguments: ["https://enosggckdxjiaqtxalhg.supabase.co", "http://localhost.evil.test:54321",
                      "http://127.0.0.1:54321/path", "http://127.0.0.1:54321?key=x",
                      "http://user:password@localhost:54321", "http://localhost:80", "https://localhost:54321"])
    func localRejectsUnsafeURLs(_ url: String) {
        #expect(throws: (any Error).self) {
            try AppConfiguration(environment: .local, url: url, publishableKey: key)
        }
    }

    @Test func stagingAcceptsOnlyTheApprovedProject() throws {
        let staging = try AppConfiguration(environment: .staging, url: "https://\(AppConfiguration.stagingHost)", publishableKey: key)
        #expect(staging.environment == .staging)
        #expect(AppConfiguration.stagingHost == "ankgfqkgflcalmlreetu.supabase.co")
    }

    @Test(arguments: ["https://otherprojectref.supabase.co", "https://ankgfqkgflcalmlreetu.supabase.co.evil.test",
                      "https://xankgfqkgflcalmlreetu.supabase.co", "http://ankgfqkgflcalmlreetu.supabase.co",
                      "https://ankgfqkgflcalmlreetu.supabase.co:8443", "http://127.0.0.1:54321"])
    func stagingRejectsEveryOtherHost(_ url: String) {
        #expect(throws: ConfigurationError.unsafeEnvironment) {
            try AppConfiguration(environment: .staging, url: url, publishableKey: key)
        }
    }

    @Test func stagingCannotTargetProduction() {
        #expect(throws: ConfigurationError.unsafeEnvironment) {
            try AppConfiguration(environment: .staging, url: "https://enosggckdxjiaqtxalhg.supabase.co", publishableKey: key)
        }
    }

    @Test(arguments: ["sb_secret_never_allowed", "garbage", "sb_publishable_", "$(MISSING)", ""])
    func rejectsMissingAndPrivilegedKeys(_ key: String) {
        #expect(throws: (any Error).self) {
            try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321", publishableKey: key)
        }
    }

    @Test func legacyKeysMustHaveAnonRole() throws {
        func token(role: String) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: ["role": role])
            let payload = data.base64EncodedString().replacingOccurrences(of: "=", with: "")
            return "header.\(payload).signature"
        }
        let anon = try token(role: "anon")
        _ = try AppConfiguration(environment: .local, url: "http://localhost:54321", publishableKey: anon)
        let elevated = try token(role: "service_role")
        #expect(throws: ConfigurationError.invalidClientKey) {
            try AppConfiguration(environment: .local, url: "http://localhost:54321", publishableKey: elevated)
        }
    }

    @Test(arguments: ["https://other.supabase.co", "https://ankgfqkgflcalmlreetu.supabase.co.evil.test",
                      "https://enosggckdxjiaqtxalhg.supabase.co"])
    func stagingIsExactlyPinned(_ url: String) {
        #expect(throws: ConfigurationError.unsafeEnvironment) {
            try AppConfiguration(environment: .staging, url: url, publishableKey: key)
        }
    }

    @Test func productionIsRefusedEvenWithApprovedHost() {
        #expect(throws: ConfigurationError.unsafeEnvironment) {
            try AppConfiguration(environment: .production, url: "https://enosggckdxjiaqtxalhg.supabase.co", publishableKey: key)
        }
    }

    @Test func unknownEnvironmentFails() {
        #expect(throws: ConfigurationError.invalidEnvironment) {
            try AppConfiguration(values: ["KizukiEnvironment": "dev"])
        }
    }
}
