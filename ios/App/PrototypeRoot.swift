import KizukiChatFeature
import KizukiCore
import KizukiDesignSystem
import KizukiHomeFeature
import KizukiMyProjectsFeature
import KizukiOnboardingFeature
import KizukiProfileFeature
import KizukiSearchFeature
import KizukiSettingsFeature
import KizukiSukiFeature
#if DEBUG
import KizukiTestSupport
#endif
import SwiftUI

#if DEBUG
/// Fixture-backed prototype shell: entry → onboarding → five tabs. Composes the feature modules (the app target is the only place
/// that knows all of them) and resolves `AppRoute` / `AppSheet` to views. Debug builds only.
struct PrototypeRoot: View {
    @State var store: AppStore
    @State private var router = AppRouter()
    @State private var phase: Phase = .loading
    let launchScreen: String?

    enum Phase: Equatable { case loading, entry(EntryScreen), main }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                KizukiTheme.charcoal.overlay(ProgressView().tint(KizukiTheme.cream))
            case let .entry(start):
                EntryFlow(start: start, autoAdvanceSplash: launchScreen == nil, initial: store.own) { draft in
                    let saved = await store.completeOnboarding(draft)
                    if saved {
                        router.tab = draft.goal == .explore ? .search : .home
                        withAnimation { phase = .main }
                    }
                    return saved
                }
            case .main:
                MainTabs()
            }
        }
        .environment(store).environment(router)
        .preferredColorScheme(.dark).tint(KizukiTheme.orange)
        .ignoresSafeArea(.keyboard, edges: [])
        .task {
            KizukiFonts.register()
            await store.load()
            if let id = launchScreen, let entry = EntryScreen(id: id) { phase = .entry(entry); return }
            if let id = launchScreen, let screen = GalleryScreen(rawValue: id) { screen.apply(store: store, router: router); phase = .main; return }
            router.tab = store.own.goal == .explore ? .search : .home
            phase = store.own.onboardingCompleted == true ? .main : .entry(.splash)
        }
    }
}


struct MainTabs: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    init() {
        KizukiFonts.register()
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(KizukiTheme.charcoal)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(KizukiTheme.babyBlueIcons)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(KizukiTheme.orange)
        UITabBar.appearance().unselectedItemTintColor = UIColor(KizukiTheme.babyBlueIcons)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var router = router
        // System TabView (floating glass bar on iOS 26), icon-only (decisions 32, 56) with Kizuki's own template icons. One NavigationStack per tab.
        TabView(selection: $router.tab) {
            stack(.home) { HomeView() }.tabItem { KizukiIcon.tabHome.image.accessibilityLabel("Home") }.tag(AppTab.home)
            stack(.search) { SearchView() }.tabItem { KizukiIcon.tabSearch.image.accessibilityLabel("Search") }.tag(AppTab.search)
            stack(.suki) { SukiView() }.tabItem { KizukiIcon.tabSuki.image.accessibilityLabel("Suki") }.tag(AppTab.suki)
            stack(.myProjects) { MyProjectsView() }.tabItem { KizukiIcon.tabMyProjects.image.accessibilityLabel("My Projects") }.tag(AppTab.myProjects)
            stack(.profile) { ProfileView(personID: store.me.id, embedsInTab: true) }.tabItem { KizukiIcon.tabProfile.image.accessibilityLabel("Profile") }.tag(AppTab.profile)
        }
        .sheet(item: $router.sheet) { sheet in
            NavigationStack { sheetContent(sheet) }
                .toolbarBackground(KizukiTheme.charcoal, for: .navigationBar)
                .environment(store).environment(router).preferredColorScheme(.dark).tint(KizukiTheme.orange)
        }
    }

    private func stack<Root: View>(_ tab: AppTab, @ViewBuilder root: () -> Root) -> some View {
        @Bindable var router = router
        let path = Binding(get: { router.paths[tab] ?? [] }, set: { router.paths[tab] = $0 })
        return NavigationStack(path: path) {
            root()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                        .toolbarBackground(KizukiTheme.charcoal, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
        }
    }

    @ViewBuilder private func destination(_ route: AppRoute) -> some View {
        switch route {
        case let .profile(id): ProfileView(personID: id)
        case let .project(id):
            if let project = store.project(id), store.isOwner(project) { OwnerProjectView(projectID: id) } else { ProjectDetailView(projectID: id) }
        case let .request(id): RequestDetailView(requestID: id)
        case let .conversation(id): ChatThreadView(personID: id)
        case .inbox: InboxView()
        case .settings: SettingsRootView()
        case let .settingsPage(page): SettingsPageView(page: page)
        case let .collabPhoto(id): CollabPhotoView(photoID: id)
        case .deleteAccount: DeleteAccountView()
        }
    }

    @ViewBuilder private func sheetContent(_ sheet: AppSheet) -> some View {
        switch sheet {
        case let .compose(person, project): RequestComposerView(personID: person, projectID: project)
        case .createProject: CreateProjectView()
        case .postCollab: PostCollabView()
        case .editProfile: EditProfileView()
        case let .report(id): ReportSheet(personID: id)
        }
    }
}

/// Every non-entry screen id the launch router can open directly: `-screen <id>`.
/// Entry and onboarding ids come from `EntryScreen.all`. Keep `scripts/screenshot-gallery.sh` in sync (a unit test checks it).
enum GalleryScreen: String, CaseIterable {
    case home, projectDetail = "project-detail", requestForm = "request-form"
    case search, searchPost = "search-post"
    case sukiCrew = "suki-crew", sukiEmpty = "suki-empty", sukiRequests = "suki-requests", sukiSent = "suki-sent", requestDetail = "request-detail"
    case sukiCreate = "suki-create", createProject = "create-project", postCollab = "post-collab"
    case myProjects = "my-projects", myProjectOwner = "my-project-owner"
    case profile, profileOther = "profile-other", profileEdit = "profile-edit", report
    case chatList = "chat-list", chat
    case settings, settingsAccount = "settings-account", settingsPrivacy = "settings-privacy", settingsDelete = "settings-delete"

    @MainActor func apply(store: AppStore, router: AppRouter) {
        let f = FixtureData.self
        switch self {
        case .home: router.tab = .home
        case .projectDetail: router.tab = .home; router.paths[.home] = [.project(f.projectID(4))]
        case .requestForm:
            router.tab = .home; router.paths[.home] = [.project(f.projectID(7))]
            router.sheet = .compose(personID: f.personID(5), projectID: f.projectID(7))
        case .search: router.tab = .search
        case .searchPost: router.tab = .search; router.paths[.search] = [.collabPhoto(f.photos[1].id)]
        case .sukiCrew: router.tab = .suki; router.sukiSection = .crew
        case .sukiEmpty:
            router.tab = .suki; router.sukiSection = .crew
            // Everyone leaves the Crew, so the empty state with Suki shows.
            Task { for person in store.crew { await store.removeFromCrew(person.id) } }
        case .sukiRequests: router.tab = .suki; router.sukiSection = .requests
        case .sukiSent: router.tab = .suki; router.sukiSection = .requests; router.showsSentRequests = true
        case .requestDetail: router.tab = .suki; router.sukiSection = .requests; router.paths[.suki] = [.request(f.requestID(0))]
        case .sukiCreate: router.tab = .suki; router.sukiSection = .create
        case .createProject: router.tab = .suki; router.sukiSection = .create; router.sheet = .createProject
        case .postCollab: router.tab = .suki; router.sukiSection = .create; router.sheet = .postCollab
        case .myProjects: router.tab = .myProjects
        case .myProjectOwner: router.tab = .myProjects; router.paths[.myProjects] = [.project(f.projectID(2))]
        case .profile: router.tab = .profile
        case .profileOther: router.tab = .home; router.paths[.home] = [.profile(f.personID(8))]
        case .profileEdit: router.tab = .profile; router.sheet = .editProfile
        case .report: router.tab = .home; router.paths[.home] = [.profile(f.personID(8))]; router.sheet = .report(f.personID(8))
        case .chatList: router.tab = .home; router.paths[.home] = [.inbox]
        case .chat: router.tab = .suki; router.paths[.suki] = [.conversation(f.personID(1))]
        case .settings: router.tab = .home; router.paths[.home] = [.settings]
        case .settingsAccount: router.tab = .home; router.paths[.home] = [.settings, .settingsPage(.account)]
        case .settingsPrivacy: router.tab = .home; router.paths[.home] = [.settings, .settingsPage(.privacy)]
        case .settingsDelete: router.tab = .home; router.paths[.home] = [.settings, .settingsPage(.account), .deleteAccount]
        }
    }
}
#endif
