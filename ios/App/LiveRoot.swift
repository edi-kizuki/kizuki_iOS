import KizukiCore
import KizukiDesignSystem
import KizukiFoundationFeature
import KizukiInfrastructure
import SwiftUI

/// Live auth gates the existing screen shell. Unimplemented gates remain explicit until B04/B05.
struct LiveRoot: View {
    let session: AppSession
    let dependencies: Dependencies
    @State private var connectionStatus: String?
    @State private var checkingConnection = false
    @State private var email = ""
    @State private var password = ""
    @State private var signingIn = false
    @State private var signInFailed = false

    private var backend: SupabaseBackend? { dependencies.sessions as? SupabaseBackend }

    var body: some View {
        Group {
            if session.phase == .main, let scope = session.scope {
                LiveTabs(session: session, dependencies: dependencies, scope: scope)
                    .id(scope.generation)
            } else if session.phase == .entry, let backend {
                Form {
                    Section("Sign in to an existing account") {
                        TextField("Email", text: $email)
                            .textContentType(.username).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(.password)
                        Button(signingIn ? "Signing in…" : "Sign in") {
                            signingIn = true
                            signInFailed = false
                            Task {
                                defer { signingIn = false; password = "" }
                                do { try await backend.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
                                catch { signInFailed = true }
                            }
                        }
                        .disabled(signingIn || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                        if signInFailed { Text("Couldn’t sign in. Check your credentials and connection.") }
                    }
                    Section {
                        Text("Account creation, email verification, password recovery, and onboarding are not available in this live build.")
                    }
                }
            } else {
                FoundationRoot(session: session, observesSession: false)
            }
        }
        .safeAreaInset(edge: .top) {
            if let backend {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live · \(backend.environment.rawValue.capitalized)").font(.headline)
                    Button(checkingConnection ? "Checking…" : "Check connection") {
                        checkingConnection = true
                        Task {
                            connectionStatus = await backend.connectionStatus()
                            checkingConnection = false
                        }
                    }.disabled(checkingConnection)
                    if let connectionStatus { Text(connectionStatus).font(.caption) }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .accessibilityIdentifier("liveConnectionStatus")
            }
        }
        .task { await session.observe() }
    }
}

private struct LiveTabs: View {
    let session: AppSession
    let scope: SessionScope
    @State private var store: AppStore
    @State private var router = AppRouter()

    init(session: AppSession, dependencies: Dependencies, scope: SessionScope) {
        self.session = session
        self.scope = scope
        _store = State(initialValue: AppStore(dependencies: dependencies))
    }

    private var unavailable: some View {
        VStack(spacing: 20) {
            Text("Live features are not available yet.").accessibilityIdentifier("liveUnavailable")
            Button("Sign out") { Task { await session.signOut() } }.accessibilityIdentifier("signOutButton")
            if session.signOutFailed { Text("Couldn’t sign out. Try again.") }
        }
    }

    var body: some View {
        Group {
            if store.isLoaded {
                #if DEBUG
                MainTabs().environment(store).environment(router)
                #else
                unavailable
                #endif
            } else if store.lastError != nil {
                unavailable
            } else { ProgressView("Loading…") }
        }
        .safeAreaInset(edge: .top) {
            if session.profileRefreshFailed {
                HStack {
                    Text("Couldn’t refresh your profile.")
                    Button("Retry") { session.refreshProfile() }
                }.padding().accessibilityIdentifier("profileRefreshError")
            }
        }
        .tint(KizukiTheme.orange)
        .task { await store.load() }
    }
}
