#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

/// Conversation list. Only Crew members appear: chat opens after an accepted request (decision 11).
public struct InboxView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = ""
    public init() {}

    private var list: [Conversation] {
        store.chatList.filter { c in query.isEmpty || (store.person(c.personID)?.name ?? "").localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        PageScroll(spacing: 12) {
            KizukiSearchField("Search your chats", text: $query)
            if list.isEmpty {
                KizukiEmptyState(title: query.isEmpty ? "No chats yet" : "No chats found",
                                 message: query.isEmpty ? "Chats open when a request is accepted. Find your people in Suki." : "Try another name from your Crew.")
            }
            ForEach(list) { conversation in
                if let person = store.person(conversation.personID) {
                    Button { router.push(.conversation(person.id)) } label: {
                        PersonRow(id: person.id, name: person.name, subtitle: conversation.messages.last?.text ?? "Say hello", trailing: "chevron.right", portraitAsset: person.portraitAsset, portraitData: person.portraitData)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(KizukiTheme.grey)
                }
            }
        }
        .navigationTitle("Messages").navigationBarTitleDisplayMode(.inline)
    }
}

public struct ChatThreadView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let personID: UUID
    @State private var draft = ""
    @State private var confirmingRemoval = false
    public init(personID: UUID) { self.personID = personID }

    public var body: some View {
        if let person = store.person(personID), let conversation = store.conversation(with: personID) {
            VStack(spacing: 0) {
                if let title = conversation.projectTitle {
                    Text("About \(title)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                        .frame(maxWidth: .infinity).padding(.vertical, 8).background(KizukiTheme.grey.opacity(0.5))
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(conversation.messages) { message in
                                Text(message.text).font(KizukiTheme.body(15)).padding(.horizontal, 16).padding(.vertical, 12)
                                    .foregroundStyle(KizukiTheme.charcoal)
                                    .background(KizukiTheme.cream, in: bubble(message.fromMe))
                                    .frame(maxWidth: 290, alignment: message.fromMe ? .trailing : .leading)
                                    .frame(maxWidth: .infinity, alignment: message.fromMe ? .trailing : .leading)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onAppear { if let last = conversation.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                    .onChange(of: conversation.messages.count) { if let last = conversation.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                HStack(spacing: 10) {
                    TextField(dynamicTypeSize.isAccessibilitySize ? "Message" : "Message \(person.firstName)", text: $draft, axis: .vertical).lineLimit(1...5).font(KizukiTheme.body(16))
                        .accessibilityLabel("Message \(person.firstName)")
                    Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundStyle(draft.isEmpty ? KizukiTheme.grey : KizukiTheme.orange).frame(width: 44, height: 44) }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Send")
                }
                .padding(.horizontal, 16).frame(minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(KizukiTheme.cream, lineWidth: 0.6))
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(KizukiTheme.charcoal).foregroundStyle(KizukiTheme.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button { router.push(.profile(person.id)) } label: {
                        HStack(spacing: 8) { PersonAvatar(person.id, size: 28, portraitAsset: person.portraitAsset, portraitData: person.portraitData); Text(person.name).font(KizukiTheme.bodyMedium(16)) }
                    }.buttonStyle(.plain).accessibilityLabel("\(person.name), open profile")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report", systemImage: "flag") { router.sheet = .report(person.id) }
                        Button("Remove from Crew", systemImage: "person.badge.minus", role: .destructive) { confirmingRemoval = true }
                        Button("Block", systemImage: "nosign", role: .destructive) { Task { await store.block(person.id); router.pop() } }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("More")
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .removeFromCrewConfirmation(isPresented: $confirmingRemoval, name: person.firstName) {
                Task { await store.removeFromCrew(person.id); router.pop() }
            }
        } else {
            ContentUnavailableView("Chat locked", systemImage: "lock", description: Text("Chats open once a request is accepted."))
        }
    }

    private func bubble(_ mine: Bool) -> UnevenRoundedRectangle {
        // Token: three 30 pt corners and one 3 pt corner; the small corner points at the sender.
        mine ? UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 30, bottomTrailingRadius: 3, topTrailingRadius: 30)
             : UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 3, bottomTrailingRadius: 30, topTrailingRadius: 30)
    }

    private func send() {
        let text = draft; draft = ""
        Task { await store.sendMessage(text, to: personID) }
    }
}
#endif
