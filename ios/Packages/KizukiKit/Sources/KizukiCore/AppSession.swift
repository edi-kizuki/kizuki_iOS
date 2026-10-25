import Foundation
import Observation

public enum ProfileState: Sendable, Equatable {
    case loading, missing, loaded(Profile), failed
}

public enum SessionState: Sendable, Equatable {
    case restoring, signedOut, unavailable
    case signedIn(userID: UUID, profile: ProfileState)
}

/// A single observer at the app root. Token refresh events do not reset the UI.
@MainActor @Observable
public final class AppSession {
    public private(set) var state: SessionState = .restoring
    public private(set) var isSigningOut = false
    public private(set) var signOutFailed = false
    @ObservationIgnored private let sessions: any SessionRepository
    @ObservationIgnored private let profiles: any ProfileRepository
    @ObservationIgnored private var profileTask: Task<Void, Never>?
    @ObservationIgnored private var isObserving = false
    @ObservationIgnored private var generation = 0

    public init(sessions: any SessionRepository, profiles: any ProfileRepository) {
        self.sessions = sessions
        self.profiles = profiles
    }

    /// Owned by SwiftUI's .task; cancellation ends the subscription.
    public func observe() async {
        guard !isObserving else { return }
        isObserving = true
        defer {
            isObserving = false
            profileTask?.cancel()
            generation += 1
            state = .restoring
        }
        for await event in await sessions.events() {
            guard !Task.isCancelled else { break }
            accept(event)
        }
    }

    public func retryProfile() {
        guard case .signedIn(let userID, _) = state else { return }
        loadProfile(for: userID)
    }

    public func signOut() async {
        guard !isSigningOut, case .signedIn(let userID, _) = state else { return }
        isSigningOut = true
        signOutFailed = false
        defer { isSigningOut = false }
        do {
            try await sessions.signOut()
            // A late response must not clear a different account that signed in meanwhile.
            if case .signedIn(let currentID, _) = state, currentID == userID { accept(.signedOut) }
        } catch {
            // Never display raw SDK errors, tokens, URLs, or user input.
            if case .signedIn(let currentID, _) = state, currentID == userID { signOutFailed = true }
        }
    }

    private func accept(_ event: SessionEvent) {
        switch event {
        case .signedOut, .unavailable:
            profileTask?.cancel()
            generation += 1
            signOutFailed = false
            state = event == .signedOut ? .signedOut : .unavailable
        case .signedIn(let userID):
            if case .signedIn(let currentID, _) = state, currentID == userID { return }
            signOutFailed = false
            loadProfile(for: userID)
        }
    }

    private func loadProfile(for userID: UUID) {
        profileTask?.cancel()
        generation += 1
        let requestGeneration = generation
        state = .signedIn(userID: userID, profile: .loading)
        profileTask = Task { [weak self, profiles] in
            let result: ProfileState
            do {
                let profile = try await profiles.ownProfile(for: userID)
                guard profile == nil || profile?.id == userID else { throw ProfileIdentityError.mismatch }
                result = profile.map(ProfileState.loaded) ?? .missing
            } catch {
                result = .failed
            }
            guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
            self.state = .signedIn(userID: userID, profile: result)
        }
    }

    private enum ProfileIdentityError: Error { case mismatch }
}
