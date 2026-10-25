import Foundation
import KizukiCore
import Supabase

/// Shared SDK instance: auth and PostgREST use the same refreshed session.
public final class SupabaseBackend: SessionRepository, ProfileRepository, Sendable {
    private let client: SupabaseClient

    public init(configuration: AppConfiguration) {
        self.client = Self.makeClient(configuration: configuration,
                                      storage: KeychainLocalStorage(service: "club.kizuki.ios.auth"),
                                      session: .shared)
    }

    /// Explicit injection for isolated SDK transport tests; never changes the live initializer.
    public init(configuration: AppConfiguration, storage: any AuthLocalStorage, session: URLSession) {
        self.client = Self.makeClient(configuration: configuration, storage: storage, session: session)
    }

    private static func makeClient(configuration: AppConfiguration, storage: any AuthLocalStorage,
                                   session: URLSession) -> SupabaseClient {
        SupabaseClient(supabaseURL: configuration.supabaseURL, supabaseKey: configuration.publishableKey,
                       options: .init(auth: .init(storage: storage,
                                                  storageKey: configuration.sessionStorageKey,
                                                  flowType: .pkce, autoRefreshToken: true,
                                                  emitLocalSessionAsInitialSession: true),
                                      global: .init(session: session, logger: nil)))
    }

    /// Stops SDK token-refresh work. Call when the backend is discarded (tests) or the app is backgrounded.
    public func stopBackgroundRefresh() {
        let auth = client.auth
        Task { await auth.stopAutoRefresh() }
    }

    public func events() async -> AsyncStream<SessionEvent> {
        let upstream = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in upstream {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                        if let session {
                            if session.isExpired {
                                continuation.yield(.unavailable)
                            } else {
                                continuation.yield(.signedIn(userID: session.user.id))
                            }
                        } else {
                            continuation.yield(.signedOut)
                        }
                    case .signedOut, .userDeleted:
                        continuation.yield(.signedOut)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func signOut() async throws {
        // Local SDK scope clears this device's Keychain session, never all devices.
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            // SDK clears local storage before its best-effort network revocation.
            // A network failure must not leave the UI claiming the device is signed in.
            if client.auth.currentSession != nil { throw error }
        }
        guard client.auth.currentSession == nil else { throw BackendError.signOutPersistenceFailed }
    }

    public func ownProfile(for userID: UUID) async throws -> Profile? {
        // Refresh if needed before querying. A locally supplied UUID is never authorization.
        let session = try await client.auth.session
        guard session.user.id == userID else { throw BackendError.identityMismatch }
        let rows: [Profile] = try await client.from("profiles")
            .select("id,handle,display_handle,avatar_path")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute().value
        guard rows.first == nil || rows.first?.id == userID else { throw BackendError.identityMismatch }
        return rows.first
    }

    private enum BackendError: Error { case identityMismatch, signOutPersistenceFailed }
}
