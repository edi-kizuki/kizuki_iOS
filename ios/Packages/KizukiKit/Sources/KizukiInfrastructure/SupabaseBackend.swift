import Foundation
import KizukiCore
import Supabase

/// Shared SDK instance: auth and PostgREST use the same refreshed session.
public final class SupabaseBackend: SessionRepository, ProfileRepository, Sendable {
    private let client: SupabaseClient
    private let restoreTimeout: Duration

    public init(configuration: AppConfiguration) {
        restoreTimeout = .seconds(10)
        self.client = Self.makeClient(configuration: configuration,
                                      storage: KeychainLocalStorage(service: "club.kizuki.ios.auth"),
                                      session: .shared)
    }

    /// Explicit injection for isolated SDK transport tests; never changes the live initializer.
    public init(configuration: AppConfiguration, storage: any AuthLocalStorage, session: URLSession, restoreTimeout: Duration = .seconds(10)) {
        self.restoreTimeout = restoreTimeout
        self.client = Self.makeClient(configuration: configuration, storage: storage, session: session)
    }

    #if DEBUG
    public static func resetAuthStorageForTesting(configuration: AppConfiguration) throws {
        guard configuration.environment == .local else { throw BackendError.identityMismatch }
        try KeychainLocalStorage(service: "club.kizuki.ios.auth").remove(key: configuration.sessionStorageKey)
    }
    #endif

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

    /// B04 calls AppSession.beginPasswordRecovery() before invoking this method.
    /// SDK 2.55.4 _verifyOTP emits signedIn only, including when type == recovery.
    public func verifyPasswordRecoveryCode(email: String, code: String) async throws {
        _ = try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
    }

    public func events() async -> AsyncStream<SessionEvent> {
        let upstream = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                var restorationDeadline: Task<Void, Never>?
                defer { restorationDeadline?.cancel() }
                for await (event, session) in upstream {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery:
                        if let session {
                            if session.isExpired {
                                // The SDK emits the expired local session BEFORE attempting refresh.
                                // Keep the root restoring, then fail honestly if refresh never settles.
                                if restorationDeadline == nil {
                                    restorationDeadline = Task { [restoreTimeout] in
                                        do { try await Task.sleep(for: restoreTimeout) } catch { return }
                                        continuation.yield(.unavailable)
                                    }
                                }
                                continue
                            }
                            restorationDeadline?.cancel()
                            restorationDeadline = nil
                            if event == .passwordRecovery {
                                continuation.yield(.passwordRecovery(userID: session.user.id))
                            } else if event == .userUpdated {
                                continuation.yield(.userUpdated(userID: session.user.id, emailVerified: session.user.emailConfirmedAt != nil))
                            } else if session.user.emailConfirmedAt == nil {
                                continuation.yield(.verificationRequired(userID: session.user.id))
                            } else {
                                continuation.yield(.signedIn(userID: session.user.id))
                            }
                        } else {
                            restorationDeadline?.cancel()
                            restorationDeadline = nil
                            continuation.yield(.signedOut)
                        }
                    case .signedOut, .userDeleted:
                        restorationDeadline?.cancel()
                        restorationDeadline = nil
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
        // B01 prefix only. B02 adds lifecycle/legal acceptance columns with its migration.
        let rows: [Profile] = try await client.from("profiles")
            .select("id,handle,display_handle,avatar_path")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute().value
        guard let profile = rows.first else { return nil }
        guard profile.id == userID else { throw BackendError.identityMismatch }
        return profile
    }

    private enum BackendError: Error { case identityMismatch, signOutPersistenceFailed }
}
