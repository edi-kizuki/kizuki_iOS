#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

/// Drafts · Published (owned published + closed, plus joined) · Past.
public struct MyProjectsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    public init() {}

    private let sections: [(String, [ProjectStatus])] = [("Drafts", [.draft]), ("Published", [.published, .closed]), ("Past", [.past])]

    public var body: some View {
        VStack(spacing: 0) {
            PageScroll(spacing: 18, horizontalPadding: 0, verticalPadding: 8) {
                HStack {
                    Text("Ideas into the world.").font(KizukiTheme.mono(13)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    Spacer()
                    KizukiIconButton(symbol: "plus", label: "Create a project") { router.sheet = .createProject }
                }
                .padding(.horizontal, KizukiTheme.pageInset)
                ForEach(sections, id: \.0) { title, statuses in
                    SectionTitle(title).padding(.horizontal, KizukiTheme.pageInset)
                    let list = store.projects(statuses)
                    if list.isEmpty {
                        Text(title == "Drafts" ? "No drafts. Start something from the + button." : "Nothing here yet.")
                            .font(KizukiTheme.body(13)).foregroundStyle(KizukiTheme.babyBlueIcons)
                            .padding(.horizontal, KizukiTheme.pageInset)
                    }
                    ForEach(list) { project in
                        Button { router.push(.project(project.id)) } label: {
                            HStack(spacing: 14) {
                                Artwork(seed: project.artSeed, height: 100).frame(width: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(project.title).font(KizukiTheme.title(24)).fixedSize(horizontal: false, vertical: true)
                                    Text("\(project.realm.rawValue) · \(project.status.rawValue)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                                    if !store.isOwner(project) { Text("Joined").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.blue) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(KizukiTheme.babyBlueIcons)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .kizukiFloatingCard(padding: KizukiTheme.cardInset)
                            .contentShape(RoundedRectangle(cornerRadius: KizukiTheme.cardRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open project, \(project.title), \(project.realm.rawValue), \(project.status.rawValue)\(store.isOwner(project) ? "" : ", Joined")")
                        .padding(.horizontal, KizukiTheme.floatingCardInset)
                    }
                }
            }
        }
        .background(KizukiTheme.charcoal)
    }
}

/// Owner tools: Edit (summary), Publish, Close, Mark done, Invite, members.
public struct OwnerProjectView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let projectID: UUID
    @State private var editing = false
    @State private var draftSummary = ""
    @State private var invited = false
    public init(projectID: UUID) { self.projectID = projectID }

    public var body: some View {
        if let project = store.project(projectID) {
            PageScroll(spacing: 16) {
                Artwork(seed: project.artSeed, height: 200, title: project.title).clipShape(RoundedRectangle(cornerRadius: 4))
                HStack {
                    Text(project.status.rawValue.uppercased()).font(KizukiTheme.mono(11)).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(project.status == .published ? KizukiTheme.blue : KizukiTheme.grey, in: Capsule())
                    Text("\(project.realm.rawValue) · \(project.compensation.rawValue)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    Spacer()
                }
                if editing {
                    KizukiTextArea("Description", text: $draftSummary)
                    PrimaryButton("Save") { var p = project; p.summary = draftSummary; Task { await store.saveProject(p); editing = false } }
                } else {
                    Text(project.summary).font(KizukiTheme.body(16))
                }
                SectionTitle("Seats and members")
                Text("\(project.memberIDs.count) of \(project.seats) seats filled").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                ForEach(project.memberIDs, id: \.self) { id in
                    if let person = store.person(id) {
                        Button { router.push(.profile(id)) } label: { PersonRow(id: id, name: person.name, subtitle: person.primaryRole, portraitAsset: person.portraitAsset, portraitData: person.portraitData) }.buttonStyle(.plain)
                    }
                }
                let waiting = store.requests.filter { $0.projectID == project.id && $0.direction == .incoming && $0.state == .pending }
                if !waiting.isEmpty {
                    Button { router.tab = .suki; router.sukiSection = .requests } label: {
                        Label("\(waiting.count) request\(waiting.count == 1 ? "" : "s") waiting in Suki", systemImage: "tray.full")
                            .font(KizukiTheme.mono(13)).frame(maxWidth: .infinity, minHeight: 48)
                            .background(KizukiTheme.grey.opacity(0.5), in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
                    }.buttonStyle(.plain)
                }
                actions(project)
            }
            .navigationTitle("Your project").navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Project not found", systemImage: "questionmark.folder")
        }
    }

    @ViewBuilder private func actions(_ project: Project) -> some View {
        switch project.status {
        case .draft:
            PrimaryButton("Publish", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) { set(project, .published) }
            OutlineButton("Edit description") { draftSummary = project.summary; editing = true }
        case .published:
            PrimaryButton(invited ? "Invite sent (demo)" : "Invite someone", color: KizukiTheme.blue) { invited = true }
            OutlineButton("Edit description") { draftSummary = project.summary; editing = true }
            OutlineButton("Mark done") { set(project, .past) }
            OutlineButton("Close project") { set(project, .closed) }
        case .closed:
            OutlineButton("Reopen") { set(project, .published) }
            OutlineButton("Mark done") { set(project, .past) }
        case .past:
            Text("This project is done.").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
        }
    }

    private func set(_ project: Project, _ status: ProjectStatus) {
        var p = project; p.status = status
        Task { await store.saveProject(p) }
    }
}
#endif
