// Related: [[012-b01-live-composition-seam]], [[2026-10-25-prototype-report]].
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

    var body: some View {
        Group {
            if store.isLoaded {
                MainTabs().environment(store).environment(router)
            } else if store.lastError != nil {
                VStack(spacing: 20) {
                    Text("Live features are not available yet.").accessibilityIdentifier("liveUnavailable")
                    Button("Sign out") { Task { await session.signOut() } }
                }
            } else { ProgressView("Loading…") }
        }
        .tint(KizukiTheme.orange)
        .task { scope.run { await store.load() } }
    }
}
