import Foundation
import Observation

public enum ProfileState: Sendable, Equatable {
    case loading, missing, loaded(Profile), failed
}

public enum SessionState: Sendable, Equatable {
    case restoring, signedOut, unavailable
    case signedIn(userID: UUID, profile: ProfileState)
}

public enum RootPhase: Sendable, Equatable {
    case restoring, unavailable, entry, verifyEmail, passwordRecovery
    case profileUnavailable, eligibility, onboarding(step: Int), main, deleted
}

/// A single observer at the app root. Token refresh events do not reset the UI.
@MainActor @Observable
public final class AppSession {
    public private(set) var state: SessionState = .restoring
    public private(set) var scope: SessionScope?
    public private(set) var requiresEmailVerification = false
    public private(set) var isPasswordRecovery = false
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
        for await event in await sessions.events() {
            guard !Task.isCancelled else { break }
            await accept(event)
        }
        profileTask?.cancel()
        generation += 1
        let old = scope
        scope = nil
        state = .restoring
        await old?.cancel()
        isObserving = false
    }

    public var phase: RootPhase {
        switch state {
        case .restoring: return .restoring
        case .signedOut: return .entry
        case .unavailable: return .unavailable
        case .signedIn(_, let profile):
            if case .loaded(let value) = profile, value.accountStatus != .active { return .deleted }
            if requiresEmailVerification { return .verifyEmail }
            if isPasswordRecovery { return .passwordRecovery }
            switch profile {
            case .loading: return .restoring
            case .failed, .missing: return .profileUnavailable
            case .loaded(let value):
                if value.eligibleAt == nil { return .eligibility }
                if value.onboardingCompletedAt == nil { return .onboarding(step: value.onboardingStep) }
                return .main
            }
        }
    }

    /// Call after every successful root-relevant mutation. Does not replace the account scope.
    public func refreshProfile() {
        guard case .signedIn(let userID, _) = state else { return }
        loadProfile(for: userID)
    }

    /// B04 calls this only after the server confirms a password update.
    public func finishPasswordRecovery() {
        isPasswordRecovery = false
        refreshProfile()
    }

    public func retryProfile() {
        refreshProfile()
    }

    public func signOut() async {
        guard !isSigningOut, case .signedIn(let userID, _) = state else { return }
        let signOutGeneration = scope?.generation
        isSigningOut = true
        signOutFailed = false
        defer { isSigningOut = false }
        do {
            try await sessions.signOut()
            // A late response must not clear a different account that signed in meanwhile.
            if case .signedIn(let currentID, _) = state, currentID == userID, scope?.generation == signOutGeneration { await accept(.signedOut) }
        } catch {
            // Never display raw SDK errors, tokens, URLs, or user input.
            if case .signedIn(let currentID, _) = state, currentID == userID, scope?.generation == signOutGeneration { signOutFailed = true }
        }
    }

    private func accept(_ event: SessionEvent) async {
        switch event {
        case .signedOut, .unavailable:
            profileTask?.cancel()
            generation += 1
            let old = scope
            scope = nil
            requiresEmailVerification = false
            isPasswordRecovery = false
            signOutFailed = false
            state = event == .signedOut ? .signedOut : .unavailable
            await old?.cancel()
        case .signedIn(let userID):
            await activate(userID)
        case .verificationRequired(let userID):
            await activate(userID)
            if scope?.userID == userID { requiresEmailVerification = true }
        case .passwordRecovery(let userID):
            await activate(userID)
            if scope?.userID == userID { requiresEmailVerification = false; isPasswordRecovery = true }
        case .userUpdated(let userID, let emailVerified):
            await activate(userID)
            if scope?.userID == userID {
                requiresEmailVerification = !emailVerified
                refreshProfile()
            }
        }
    }

    private func activate(_ userID: UUID) async {
        if scope?.userID == userID { return } // A token refresh preserves the screen and recovery gate.
        profileTask?.cancel()
        generation += 1
        let transition = generation
        let old = scope
        scope = nil
        state = .restoring
        await old?.cancel()
        guard generation == transition, !Task.isCancelled else { return }
        scope = SessionScope(userID: userID, generation: transition)
        requiresEmailVerification = false
        isPasswordRecovery = false
        signOutFailed = false
        loadProfile(for: userID)
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
