import Foundation
import Observation

public enum AppTab: Int, CaseIterable, Hashable, Sendable { case home, search, suki, myProjects, profile }

public enum SukiSection: Int, Hashable, Sendable, CaseIterable { case crew, requests, create }

public enum SettingsPage: String, Hashable, Sendable, CaseIterable {
    case account = "Profile & account", notifications = "Notifications", privacy = "Privacy & safety"
    case help = "Help & support", legal = "Legal & about"
}

public enum AppRoute: Hashable, Sendable {
    case profile(UUID), project(UUID), request(UUID), conversation(UUID), inbox
    case settings, settingsPage(SettingsPage), collabPhoto(UUID), deleteAccount
}

public enum AppSheet: Identifiable, Hashable, Sendable {
    /// Request / invite form. Either a person or a project is the target.
    case compose(personID: UUID, projectID: UUID?)
    case createProject, postCollab, editProfile, report(UUID)
    public var id: String {
        switch self {
        case let .compose(person, project): "compose-\(person)-\(project?.uuidString ?? "")"
        case .createProject: "createProject"
        case .postCollab: "postCollab"
        case .editProfile: "editProfile"
        case let .report(id): "report-\(id)"
        }
    }
}

/// One navigation path per tab; `AppRoute` lives in Core so features never import each other.
@MainActor @Observable
public final class AppRouter {
    public var tab: AppTab = .home
    public var paths: [AppTab: [AppRoute]] = [:]
    public var sheet: AppSheet?
    public var sukiSection: SukiSection = .crew
    public var showsSentRequests = false
    public init() {}

    public func push(_ route: AppRoute) { paths[tab, default: []].append(route) }
    public func popToRoot() { paths[tab] = [] }
    public func pop() { if paths[tab]?.isEmpty == false { paths[tab]?.removeLast() } }
    /// After accepting a request: go to Suki > Crew and open the new chat.
    public func openConversation(with personID: UUID) {
        tab = .suki; sukiSection = .crew; sheet = nil
        paths[.suki] = [.conversation(personID)]
    }
}
