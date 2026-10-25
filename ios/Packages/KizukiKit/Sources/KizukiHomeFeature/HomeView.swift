import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    public init() {}

    private var draft: Project? { store.projects([.draft]).first { $0.ownerID == store.me.id } }

    public var body: some View {
        VStack(spacing: 0) {
            KizukiTopBar(onSettings: { router.push(.settings) }, onInbox: { router.push(.inbox) })
            ScrollView {
                VStack(spacing: 20) {
                    if store.own.goal == .collaborate, store.own.intent == .start, let draft {
                        Button { router.push(.project(draft.id)) } label: {
                            HStack {
                                Image(systemName: "pencil.and.outline")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Finish your project").font(KizukiTheme.bodyMedium(17))
                                    Text(draft.title).font(KizukiTheme.mono(11))
                                }
                                Spacer(); Image(systemName: "arrow.right")
                            }
                            .padding(20).foregroundStyle(KizukiTheme.cream).background(KizukiTheme.blue, in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
                        }
                        .buttonStyle(.plain).padding(.horizontal, 12)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Recommended projects")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(store.visibleProjectRecommendations, id: \.item.id) { rec in
                                    ProjectCard(project: rec.item, reasons: rec.reasons) { router.push(.project(rec.item.id)) }.frame(width: 290)
                                }
                            }
                        }
                    }
                    .kizukiCard().padding(.horizontal, 12)
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("People that you might like")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 18) {
                            ForEach(store.visiblePeopleRecommendations.prefix(9), id: \.item.id) { rec in
                                Button { router.push(.profile(rec.item.id)) } label: {
                                    VStack(spacing: 6) {
                                        PersonAvatar(rec.item.id, size: 72)
                                        Text(rec.item.name).font(KizukiTheme.bodyMedium(13)).lineLimit(1)
                                        Text(rec.item.primaryRole).font(KizukiTheme.body(11)).foregroundStyle(KizukiTheme.babyBlueIcons).lineLimit(1)
                                        ReasonChips(Array(rec.reasons.prefix(1)))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain).accessibilityLabel("\(rec.item.name), \(rec.item.primaryRole)")
                            }
                        }
                    }
                    .kizukiCard().padding(.horizontal, 12)
                }
                .padding(.vertical, 20)
            }
            .background(KizukiTheme.babyBlue)
        }
        .background(KizukiTheme.charcoal)
    }
}

public struct ProjectCard: View {
    let project: Project
    let reasons: [String]
    let action: () -> Void
    public init(project: Project, reasons: [String], action: @escaping () -> Void) { self.project = project; self.reasons = reasons; self.action = action }
    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Artwork(seed: project.artSeed, height: 200, title: project.title)
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title).font(KizukiTheme.bodyMedium(20)).lineLimit(1)
                    Text("\(project.city) · \(project.realm.rawValue)").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    ReasonChips(reasons)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(KizukiTheme.grey)
            }
            .foregroundStyle(KizukiTheme.cream)
        }
        .buttonStyle(.plain).accessibilityLabel("Open project, \(project.title)")
    }
}
