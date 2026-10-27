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
            let ephemeral = arguments.contains("-fixtures") || launchScreen != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            _prototypeStore = State(initialValue: AppStore(dependencies: FixtureBackend.dependencies(storageURL: ephemeral ? nil : FixtureBackend.runtimeStorageURL)))
            _session = State(initialValue: nil)
            configurationError = nil
            liveDependencies = nil
            return
        }
        _prototypeStore = State(initialValue: nil)
        // UI-test launches exercise LiveRoot with explicit session/profile phases.
        if arguments.contains("--ui-testing") {
            let backend = UITestBackend()
            _session = State(initialValue: AppSession(sessions: backend, profiles: backend))
            configurationError = nil
            liveDependencies = .live(sessions: backend, profiles: backend)
            return
        }
        #endif
        do {
            let values = Bundle.main.infoDictionary?.compactMapValues { $0 as? String } ?? [:]
            let configuration = try AppConfiguration(values: values)
            let dependencies: Dependencies
            #if DEBUG
            if arguments.contains("-isolatedAuthStorage") {
                dependencies = .live(backend: try SupabaseBackend.localSmokeBackend(configuration: configuration))
            } else { dependencies = .live(configuration: configuration) }
            #else
            dependencies = .live(configuration: configuration)
            #endif
            liveDependencies = dependencies
            _session = State(initialValue: AppSession(sessions: dependencies.sessions, profiles: dependencies.profiles,
                recovery: PasswordRecoveryState(defaults: .standard, namespace: configuration.sessionStorageKey)))
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
        let profile = phase != "entry"
        return AsyncStream { continuation in
            continuation.yield(profile ? .signedIn(userID: userID) : .signedOut)
            // Stay subscribed until SwiftUI cancels its root task.
        }
    }
    private var phase: String {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--ui-testing-phase"), arguments.indices.contains(index + 1) { return arguments[index + 1] }
        return arguments.contains("--ui-testing-profile") ? "eligibility" : "entry"
    }
    func ownProfile(for userID: UUID) async throws -> Profile? {
        Profile(id: userID, handle: "creator", displayHandle: "Creator",
                onboardingCompletedAt: phase == "main" ? .distantPast : nil,
                eligibleAt: phase == "main" || phase == "onboarding" ? .distantPast : nil)
    }
    func signOut() async throws {}
}
#endif
