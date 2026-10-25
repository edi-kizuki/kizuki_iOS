import KizukiCore
import KizukiFoundationFeature
import KizukiInfrastructure
import SwiftUI
#if DEBUG
import KizukiTestSupport
#endif

@main
struct KizukiApp: App {
    @State private var session: AppSession?
    private let liveDependencies: Dependencies?
    private let configurationError: String?
    #if DEBUG
    // Debug launches show the fixture-backed prototype unless `-live` is passed (`-fixtures` forces it).
    // `-screen <id>` opens one screen directly; see GalleryScreen and scripts/screenshot-gallery.sh.
    @State private var prototypeStore: AppStore?
    private let launchScreen: String?
    #endif

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        launchScreen = arguments.firstIndex(of: "-screen").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        if !arguments.contains("--ui-testing"), arguments.contains("-fixtures") || !arguments.contains("-live") {
            _prototypeStore = State(initialValue: AppStore(dependencies: .fixture))
            _session = State(initialValue: nil)
            configurationError = nil
            liveDependencies = nil
            return
        }
        _prototypeStore = State(initialValue: nil)
        // UI-test launches use the foundation fixtures; `-live` launches use the SDK.
        if arguments.contains("--ui-testing") {
            let backend = UITestBackend()
            _session = State(initialValue: AppSession(sessions: backend, profiles: backend))
            configurationError = nil
            liveDependencies = nil
            return
        }
        #endif
        do {
            let values = Bundle.main.infoDictionary?.compactMapValues { $0 as? String } ?? [:]
            let configuration = try AppConfiguration(values: values)
            let dependencies = Dependencies.live(configuration: configuration)
            liveDependencies = dependencies
            _session = State(initialValue: AppSession(sessions: dependencies.sessions, profiles: dependencies.profiles))
            configurationError = nil
        } catch {
            liveDependencies = nil
            _session = State(initialValue: nil)
            configurationError = (error as? ConfigurationError)?.errorDescription ?? "Check this build’s configuration."
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let prototypeStore { PrototypeRoot(store: prototypeStore, launchScreen: launchScreen) } else { foundation }
            #else
            foundation
            #endif
        }
    }

    @ViewBuilder private var foundation: some View {
        if let session, let liveDependencies { LiveRoot(session: session, dependencies: liveDependencies) }
        else if let session { FoundationRoot(session: session) }
        else { FoundationRoot(configurationError: configurationError ?? "Check this build’s configuration.") }
    }
}

#if DEBUG
private struct UITestBackend: SessionRepository, ProfileRepository {
    private let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    func events() async -> AsyncStream<SessionEvent> {
        let profile = ProcessInfo.processInfo.arguments.contains("--ui-testing-profile")
        return AsyncStream { continuation in
            continuation.yield(profile ? .signedIn(userID: userID) : .signedOut)
            // Stay subscribed until SwiftUI cancels its root task.
        }
    }
    func ownProfile(for userID: UUID) async throws -> Profile? {
        Profile(id: userID, handle: "creator", displayHandle: "Creator")
    }
    func signOut() async throws {}
}
#endif
