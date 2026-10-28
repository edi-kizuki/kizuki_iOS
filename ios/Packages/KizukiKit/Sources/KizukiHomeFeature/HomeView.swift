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
                    nextSteps
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
                }
                .padding(.vertical, 20)
            }
            .background(KizukiTheme.babyBlue)
        }
        .background(KizukiTheme.charcoal)
    }

    @ViewBuilder private var nextSteps: some View {
        if !store.feedPrompts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your next move").font(KizukiTheme.title(26)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(store.feedPrompts.count)").font(KizukiTheme.mono(12))
                        .accessibilityLabel("\(store.feedPrompts.count) suggestions")
                }
                .foregroundStyle(KizukiTheme.charcoal)
                .padding(.horizontal, KizukiTheme.pageInset)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        ForEach(store.feedPrompts) { promptCard($0) }
                    }
                    .padding(.horizontal, KizukiTheme.floatingCardInset)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(store.feedPrompts) { prompt in
                                promptCard(prompt)
                                    .containerRelativeFrame(.horizontal) { availableWidth, _ in
                                        min(availableWidth - 44, 340)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 8)
                    }
                    .contentMargins(.horizontal, KizukiTheme.floatingCardInset, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .accessibilityIdentifier("feed-prompts")
                }
            }
        }
    }

    private func promptCard(_ prompt: AppStore.FeedPrompt) -> some View {
        let content = promptContent(prompt)
        return Button { open(prompt) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: content.symbol).font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(content.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(content.tint).accessibilityHidden(true)
                    Spacer()
                    Text(content.category).font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
                }
                Text(content.title).font(KizukiTheme.title(26))
                Text(content.detail).font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : 40, alignment: .topLeading)
                HStack {
                    Text(content.action).font(KizukiTheme.mono(12))
                    Spacer()
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(KizukiTheme.cream)
            .kizukiFloatingCard(fill: KizukiTheme.charcoal)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feed-prompt-\(prompt.id)")
        .accessibilityHint(content.action)
    }

    private func promptContent(_ prompt: AppStore.FeedPrompt) -> (category: String, title: String, detail: String, action: String, symbol: String, tint: Color) {
        switch prompt {
        case .finishProject(let id):
            ("YOUR DRAFT", "Finish your project", "Give “\(store.project(id)?.title ?? "your project")” a few finishing touches.", "Continue draft", "pencil.and.outline", KizukiTheme.blue)
        case .reviewRequests(let count):
            ("CONNECTIONS", "A collab could start here", "\(count) \(count == 1 ? "request is" : "requests are") waiting for your reply.", "Review requests", "person.badge.plus", KizukiTheme.yellow)
        case .completeProfile:
            ("ABOUT YOU", "Let people get to know you", "\(store.discoveryDoneCount) of \(store.discoverySteps.count) basics complete. Add a little about yourself.", "Finish profile", "person.crop.circle", KizukiTheme.orange)
        case .startConversation(let id):
            ("YOUR CREW", "Every collab starts with hello", "You and \(store.person(id)?.firstName ?? "your new connection") are in each other’s Crew. Start a conversation.", "Say hello", "bubble.left.and.bubble.right", KizukiTheme.salmon)
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
