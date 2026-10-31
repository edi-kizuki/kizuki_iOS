import Foundation
import KizukiCore
import Supabase

/// Shared SDK instance: auth and PostgREST use the same refreshed session.
public final class SupabaseBackend: SessionRepository, ProfileRepository, Sendable {
    private let gate: ProbedClient
    private let restoreTimeout: Duration
    private let configuration: AppConfiguration
    private let transport: GuardedTransport
    public var environment: AppEnvironment { configuration.environment }

    public init(configuration: AppConfiguration) {
        self.configuration = configuration
        transport = GuardedTransport(configuration: configuration)
        restoreTimeout = .seconds(10)
        gate = ProbedClient(configuration: configuration,
                            storage: { KeychainLocalStorage(service: "club.kizuki.ios.auth") }, transport: transport)
    }

    /// Explicit injection for isolated SDK transport tests; never changes the live initializer.
    public init(configuration: AppConfiguration, storage: any AuthLocalStorage, session: URLSession, restoreTimeout: Duration = .seconds(10)) {
        self.configuration = configuration
        transport = GuardedTransport(configuration: configuration, session: session)
        self.restoreTimeout = restoreTimeout
        gate = ProbedClient(configuration: configuration, storage: { storage }, transport: transport)
    }

    #if DEBUG
    /// A fresh real Keychain namespace makes local signed-out smoke tests independent of prior accounts.
    /// No Keychain deletion or fixture auth backend; only the local SDK client uses this test service.
    public static func localSmokeBackend(configuration: AppConfiguration) throws -> SupabaseBackend {
        guard configuration.environment == .local else { throw BackendError.identityMismatch }
        return SupabaseBackend(configuration: configuration,
            storage: KeychainLocalStorage(service: "club.kizuki.ios.auth.local-smoke." + UUID().uuidString), session: .shared)
    }
    #endif

    public func prepare() async throws { _ = try await gate.client() }

    public func stopBackgroundRefresh() { Task { await gate.stop() } }

    public func signIn(email: String, password: String) async throws {
        let client = try await gate.client()
        _ = try await client.auth.signIn(email: email, password: password)
    }

    public func connectionStatus() async -> String {
        do { try await prepare() } catch { return "This build can’t connect to its server." }
        let endpoints = [
            ("Auth settings", "/auth/v1/settings"),
            ("Database API", "/rest/v1/"),
            ("Profile schema", "/rest/v1/profiles?select=id,handle,display_handle,avatar_path,onboarding_completed_at,eligible_at,account_status&limit=0")
        ]
        var results: [String] = []
        for (name, path) in endpoints {
            guard let url = URL(string: path, relativeTo: configuration.supabaseURL) else { continue }
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (_, response) = try await transport.session.data(for: request)
                guard let response = response as? HTTPURLResponse else {
                    results.append("\(name): unavailable")
                    continue
                }
                results.append("\(name): HTTP \(response.statusCode)")
            } catch {
                results.append("\(name): unavailable")
            }
        }
        results.append("Public endpoint checks only. User access and schema readiness require an authenticated profile read.")
        return results.joined(separator: "\n")
    }

    /// B04 calls AppSession.beginPasswordRecovery() before invoking this method.
    /// SDK 2.55.4 _verifyOTP emits signedIn only, including when type == recovery.
    public func verifyPasswordRecoveryCode(email: String, code: String) async throws {
        let client = try await gate.client()
        _ = try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
    }

    public func events() async -> AsyncStream<SessionEvent> {
        let client: SupabaseClient
        do { client = try await gate.client() }
        catch { return AsyncStream { $0.yield(.unavailable) } }
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
        let client = try await gate.client()
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
        let client = try await gate.client()
        // Refresh if needed before querying. A locally supplied UUID is never authorization.
        let session = try await client.auth.session
        guard session.user.id == userID else { throw BackendError.identityMismatch }
        // B01 prefix only. B02 adds lifecycle/legal acceptance columns with its migration.
        let rows: [Profile] = try await client.from("profiles")
            .select("id,handle,display_handle,avatar_path,onboarding_completed_at,eligible_at,account_status")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute().value
        guard let profile = rows.first else { return nil }
        guard profile.id == userID else { throw BackendError.identityMismatch }
        return profile
    }

    private enum BackendError: Error { case identityMismatch, signOutPersistenceFailed }
}
