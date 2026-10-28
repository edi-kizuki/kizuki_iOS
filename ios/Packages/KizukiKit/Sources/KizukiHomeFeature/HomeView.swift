#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            KizukiTopBar(onInbox: { router.push(.inbox) })
            ScrollView {
                VStack(spacing: 20) {
                    if let prompt = store.feedPrompts.first { promptBanner(prompt) }
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Recommended projects")
                        if store.visibleProjectRecommendations.isEmpty {
                            KizukiEmptyState(title: "Room for something new", message: "Projects will appear here as your community grows.")
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(store.visibleProjectRecommendations, id: \.item.id) { rec in
                                    ProjectCard(project: rec.item, reasons: rec.reasons) { router.push(.project(rec.item.id)) }.frame(width: 290)
                                }
                            }
                        }
                    }
                    .kizukiCard().padding(.horizontal, 12)
                    if store.feedPrompts.count > 1 { promptBanner(store.feedPrompts[1]) }
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("People that you might like")
                        if store.visiblePeopleRecommendations.isEmpty {
                            KizukiEmptyState(title: "Your people are on their way", message: "Check back for new creators to collaborate with.")
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 18) {
                            ForEach(store.visiblePeopleRecommendations.prefix(9), id: \.item.id) { rec in
                                Button { router.push(.profile(rec.item.id)) } label: {
                                    VStack(spacing: 6) {
                                        PersonAvatar(rec.item.id, size: 72, portraitAsset: rec.item.portraitAsset)
                                        Text(rec.item.name).font(KizukiTheme.bodyMedium(13)).multilineTextAlignment(.center)
                                        Text(rec.item.primaryRole).font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons).multilineTextAlignment(.center)
                                        ReasonChips(Array(rec.reasons.prefix(1)))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain).accessibilityLabel("\(rec.item.name), \(rec.item.primaryRole)")
                            }
                        }
                    }
                    .kizukiCard().padding(.horizontal, 12)
                    ForEach(Array(store.feedPrompts.dropFirst(2))) { promptBanner($0) }
                }
                .padding(.vertical, 20)
            }
            .accessibilityIdentifier("feed-scroll")
            .background(KizukiTheme.babyBlue)
        }
        .background(KizukiTheme.charcoal)
    }

    private func promptBanner(_ prompt: AppStore.FeedPrompt) -> some View {
        let content = promptContent(prompt)
        return Button { open(prompt) } label: {
            HStack(spacing: 10) {
                Image(systemName: content.symbol).font(.system(size: 15))
                    .foregroundStyle(KizukiTheme.blue)
                    .accessibilityHidden(true)
                Text(content.title).font(KizukiTheme.body(14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(KizukiTheme.charcoal.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .foregroundStyle(KizukiTheme.charcoal)
            .background(KizukiTheme.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feed-prompt-\(prompt.id)")
        .accessibilityLabel("\(content.title). \(content.detail)")
        .accessibilityHint(content.action)
        .padding(.horizontal, KizukiTheme.floatingCardInset)
    }

    private func promptContent(_ prompt: AppStore.FeedPrompt) -> (title: String, detail: String, action: String, symbol: String) {
        switch prompt {
        case .finishProject(let id):
            ("Finish your project", store.project(id)?.title ?? "Pick up where you left off.", "Continue draft", "pencil.and.outline")
        case .reviewRequests(let count):
            ("\(count) collab \(count == 1 ? "request" : "requests")", "See who wants to make something with you.", "Review requests", "person.badge.plus")
        case .completeProfile:
            ("A little more about you", "Finish your profile so people can get to know you.", "Finish profile", "person.crop.circle")
        case .startConversation(let id):
            ("Say hello to \(store.person(id)?.firstName ?? "your new connection")", "Start a conversation with your new Crew connection.", "Say hello", "bubble.left.and.bubble.right")
        }
    }

    private func open(_ prompt: AppStore.FeedPrompt) {
        switch prompt {
        case .finishProject(let id): router.push(.project(id))
        case .reviewRequests:
            router.tab = .suki
            router.sukiSection = .requests
            router.showsSentRequests = false
            router.popToRoot()
        case .completeProfile: router.sheet = .editProfile
        case .startConversation(let id): router.openConversation(with: id)
        }
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
                    Text(project.title).font(KizukiTheme.bodyMedium(20)).fixedSize(horizontal: false, vertical: true)
                    Text("\(project.city) · \(project.realm.rawValue)").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    ReasonChips(reasons)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(KizukiTheme.grey)
            }
            .foregroundStyle(KizukiTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: KizukiTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain).accessibilityLabel("Open project, \(project.title)")
    }
}
#endif
