import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct FoundationRoot: View {
    private let session: AppSession?
    private let observesSession: Bool
    private let configurationError: String?

    public init(session: AppSession, observesSession: Bool = true) {
        self.observesSession = observesSession
        self.session = session
        self.configurationError = nil
    }

    public init(configurationError: String) {
        self.observesSession = false
        self.session = nil
        self.configurationError = configurationError
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KizukiTheme.spacing) {
                Text("kizuki").font(.largeTitle.weight(.black)).foregroundStyle(KizukiTheme.accent)
                    .accessibilityLabel("Kizuki")
                if let session {
                    sessionContent(session)
                } else {
                    Image(systemName: "wrench.and.screwdriver").font(.largeTitle).accessibilityHidden(true)
                    Text("Setup needed").font(.title.bold()).accessibilityIdentifier("configurationTitle")
                    Text(configurationError ?? "Check this build’s configuration.")
                    Text("Add local backend configuration, then relaunch the app.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(KizukiTheme.spacing)
            .padding(.top, 40)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(KizukiTheme.canvas.ignoresSafeArea())
        .foregroundStyle(KizukiTheme.cream)
        .tint(KizukiTheme.accent)
        .preferredColorScheme(.dark)
        .task { if observesSession { await session?.observe() } }
    }

    @ViewBuilder private func sessionContent(_ session: AppSession) -> some View {
        switch session.state {
        case .restoring:
            ProgressView("Restoring your session…")
        case .unavailable:
            Text("Your session is unavailable").font(.title.bold())
            Text("Check your connection and reopen Kizuki.")
        case .signedOut:
            Text("Find your people.\nMake something real.")
                .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("entryTitle")
            Text("A place for your next creative collaboration.").accessibilityIdentifier("entrySubtitle")
            Text("Sign-in will be available in a future build.").foregroundStyle(.secondary)
        case .signedIn(let userID, let profile):
            ProfileAvatar(profileID: userID).frame(width: 112, height: 112)
            if session.phase == .verifyEmail {
                Text("Verify your email").accessibilityIdentifier("verifyEmailTitle")
                Text("Verification will be available in a future build.")
            } else if session.phase == .passwordRecovery {
                Text("Set a new password").accessibilityIdentifier("passwordRecoveryTitle")
                Text("Password updates will be available in a future build.")
            } else {
                switch profile {
                case .loading:
                    ProgressView("Loading your profile…")
                case .missing:
                    Text("Your profile isn’t available yet").font(.title.bold())
                    Text("Try again in a moment.")
                    retryButton(session)
                case .failed:
                    Text("Couldn’t load your profile").font(.title.bold())
                    Text("Check your connection and try again.")
                    retryButton(session)
                case .loaded(let profile):
                    Text(profile.displayHandle ?? profile.handle ?? "Your profile").font(.title.bold())
                        .accessibilityIdentifier("profileTitle")
                    switch session.phase {
                    case .eligibility: Text("Confirm Terms and age").accessibilityIdentifier("eligibilityTitle")
                    case .onboarding: Text("Complete your profile").accessibilityIdentifier("onboardingTitle")
                    case .deleted: Text("This account is unavailable").accessibilityIdentifier("deletedTitle")
                    default: Text("Your creative space is taking shape.").foregroundStyle(.secondary)
                    }
                    if session.phase != .main {
                        Text("This step will be available in a future build.").foregroundStyle(.secondary)
                    }
                }
            }
            Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                .buttonStyle(KizukiButtonStyle()).disabled(session.isSigningOut).accessibilityIdentifier("signOutButton")
            if session.signOutFailed {
                Text("Couldn’t sign out. Try again.").accessibilityIdentifier("signOutError")
            }
        }
    }

    private func retryButton(_ session: AppSession) -> some View {
        Button("Try again") { session.retryProfile() }.buttonStyle(KizukiButtonStyle())
    }
}
