import KizukiCore
import KizukiDesignSystem
import KizukiFoundationFeature
import SwiftUI

/// Live auth gates the existing screen shell. Unimplemented gates remain explicit until B04/B05.
struct LiveRoot: View {
    let session: AppSession
    let dependencies: Dependencies

    var body: some View {
        Group {
            if session.phase == .main, let scope = session.scope {
                LiveTabs(session: session, dependencies: dependencies, scope: scope)
                    .id(scope.generation)
            } else {
                FoundationRoot(session: session, observesSession: false)
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
