// Related: [[012-b01-live-composition-seam]], [[2026-10-25-b01-report]].
import Foundation
import KizukiCore
import KizukiInfrastructure
import Supabase
import Testing

/// Read-only smoke against the existing local stack. No users or schema are created.
struct LocalLiveSessionTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["KIZUKI_LIVE_TESTS"] == "1"))
    func localHealthAndSignedOutSession() async throws {
        let configuration = try AppConfiguration(environment: .local, url: "http://127.0.0.1:54321",
            publishableKey: ProcessInfo.processInfo.environment["KIZUKI_LOCAL_PUBLIC_KEY"] ?? "")
        var request = URLRequest(url: configuration.supabaseURL.appendingPathComponent("auth/v1/health"))
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        let (_, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let backend = SupabaseBackend(configuration: configuration, storage: EmptySessionStorage(), session: .shared)
        var events = await backend.events().makeAsyncIterator()
        #expect(await events.next() == .signedOut)
    }
}

private struct EmptySessionStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}
