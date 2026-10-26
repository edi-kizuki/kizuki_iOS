#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

/// Visitor view of a project (not the owner's). Owner tools live in KizukiMyProjectsFeature.
public struct ProjectDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let projectID: UUID
    public init(projectID: UUID) { self.projectID = projectID }

    public var body: some View {
        if let project = store.project(projectID), let owner = store.person(project.ownerID) {
            let isMember = project.memberIDs.contains(store.me.id)
            let pending = store.pendingRequest(for: owner.id, project: project.id) != nil
            PageScroll(spacing: 16) {
                Artwork(seed: project.artSeed, height: 230, title: project.title).clipShape(RoundedRectangle(cornerRadius: 4))
                Button { router.push(.profile(owner.id)) } label: {
                    PersonRow(id: owner.id, name: owner.name, subtitle: "Project owner · \(owner.primaryRole)")
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 14) {
                    Text(project.title).font(KizukiTheme.bodyBold(18)).foregroundStyle(KizukiTheme.charcoal)
                    Text(project.summary).font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.charcoal)
                    detailRow("Category", project.realm.rawValue)
                    detailRow("Compensation", project.compensation.rawValue)
                    detailRow("Time", project.timeCommitment.rawValue)
                    detailRow("Set up", "\(project.workMode.rawValue) · \(project.city)")
                    detailRow("Seats", "\(max(0, project.seats - project.memberIDs.count)) open of \(project.seats)")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Roles").font(KizukiTheme.mono(14)).foregroundStyle(KizukiTheme.charcoal)
                        HStack { ForEach(project.rolesNeeded, id: \.self) { role in
                            Text(role).font(KizukiTheme.mono(12)).padding(.horizontal, 10).padding(.vertical, 6)
                                .foregroundStyle(KizukiTheme.charcoal).overlay(Capsule().stroke(KizukiTheme.charcoal, lineWidth: 1))
                        } }
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(KizukiTheme.cream).overlay(Rectangle().stroke(KizukiTheme.blue, lineWidth: 1))
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if isMember {
                    PrimaryButton("Open chat", color: KizukiTheme.blue) { router.push(.conversation(owner.id)) }
                } else if project.status == .published {
                    PrimaryButton(pending ? "Request sent" : "Join project", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) {
                        router.sheet = .compose(personID: owner.id, projectID: project.id)
                    }
                    .disabled(pending)
                } else {
                    Text("This project is no longer open.").font(KizukiTheme.mono(13)).foregroundStyle(KizukiTheme.babyBlueIcons)
                }
                }
                .padding(.horizontal, 40).padding(.top, 8).padding(.bottom, 4).background(KizukiTheme.charcoal.opacity(0.92))
            }
            .navigationTitle(project.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report project owner", systemImage: "flag") { router.sheet = .report(owner.id) }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("More")
                }
            }
        } else {
            ContentUnavailableView("Project not found", systemImage: "questionmark.folder")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.charcoal.opacity(0.6)).frame(width: 96, alignment: .leading)
            Text(value).font(KizukiTheme.mono(13)).foregroundStyle(KizukiTheme.charcoal)
            Spacer()
        }
    }
}
#endif
