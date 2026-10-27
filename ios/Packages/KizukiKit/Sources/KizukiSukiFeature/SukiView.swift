#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

/// Suki tab: Crew (accepted connections), Requests (incoming and sent), Create. The word "Matches" is never shown (decision 44).
public struct SukiView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var removing: Person?
    public init() {}

    public var body: some View {
        @Bindable var router = router
        VStack(spacing: 14) {
            KizukiTopBar(title: "Suki", symbol: .sukiMascot, onSettings: { router.push(.settings) }, onInbox: { router.push(.inbox) })
            Picker("Suki section", selection: $router.sukiSection) {
                Text("Crew").tag(SukiSection.crew); Text("Requests").tag(SukiSection.requests); Text("Create").tag(SukiSection.create)
            }
            .pickerStyle(.segmented).padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch router.sukiSection {
                    case .crew: crew
                    case .requests: requests
                    case .create: create
                    }
                }
                .padding(20)
            }
        }
        .background(KizukiTheme.charcoal).foregroundStyle(KizukiTheme.cream)
        .removeFromCrewConfirmation(isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), name: removing?.firstName ?? "this person") {
            if let person = removing { Task { await store.removeFromCrew(person.id) } }
            removing = nil
        }
    }

    // MARK: Crew

    @ViewBuilder private var crew: some View {
        // Suki greets you above the Crew. Decorative, so VoiceOver skips it.
        HStack(alignment: .bottom, spacing: 14) {
            if !store.crew.isEmpty { SukiMascotView(height: 64) }
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle("Your Crew")
                Text("People you’re building something with.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
            Spacer(minLength: 0)
        }
        if store.crew.isEmpty {
            SukiEmptyState(title: "Your Crew starts with a yes", message: "Accepted requests land here, with a chat.")
        }
        ForEach(store.crew) { person in
            CrewCard(person: person,
                     onMessage: { router.push(.conversation(person.id)) },
                     onProfile: { router.push(.profile(person.id)) },
                     onRemove: { removing = person })
        }
    }

    // MARK: Requests

    @ViewBuilder private var requests: some View {
        @Bindable var router = router
        Picker("Direction", selection: $router.showsSentRequests) { Text("Incoming").tag(false); Text("Sent").tag(true) }
            .pickerStyle(.segmented)
        let direction: RequestDirection = router.showsSentRequests ? .outgoing : .incoming
        let list = store.requests(direction)
        if list.isEmpty {
            SukiEmptyState(title: direction == .incoming ? "No requests yet" : "Nothing sent yet",
                           message: direction == .incoming ? "When someone wishes to collab or asks to join, it lands here."
                                                           : "Wish to Collab from a profile, or Join project from a project.")
        }
        ForEach(list) { request in
            if let person = store.person(request.personID) {
                VStack(alignment: .leading, spacing: 12) {
                    Button { router.push(.request(request.id)) } label: {
                        PersonRow(id: person.id, name: person.name, subtitle: "\(request.role) · \(request.timeCommitment)", portraitAsset: person.portraitAsset)
                    }.buttonStyle(.plain)
                    Text(request.kind.label.uppercased()).font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.orange)
                    if let project = request.projectID.flatMap(store.project) { Text(project.title).font(KizukiTheme.title(22)) }
                    else { Text(direction == .incoming ? "\(person.firstName) wishes to collab" : "You wished to collab").font(KizukiTheme.title(22)) }
                    HStack {
                        stateBadge(request.state)
                        Spacer()
                        if request.state == .pending {
                            if direction == .incoming {
                                Button("Decline") { Task { await store.respond(to: request.id, with: .decline) } }
                                    .buttonStyle(.bordered).tint(KizukiTheme.babyBlue).frame(minHeight: 44)
                                Button("Accept") { accept(request) }.buttonStyle(.borderedProminent).tint(KizukiTheme.blue).frame(minHeight: 44)
                            } else {
                                Button("Withdraw") { Task { await store.respond(to: request.id, with: .withdraw) } }
                                    .buttonStyle(.bordered).tint(KizukiTheme.babyBlue).frame(minHeight: 44)
                            }
                        } else if request.state == .accepted {
                            Button("Open chat") { router.push(.conversation(person.id)) }.buttonStyle(.bordered).tint(KizukiTheme.babyBlue).frame(minHeight: 44)
                        }
                    }
                }
                .kizukiPanel()
            }
        }
    }

    private func accept(_ request: CollabRequest) {
        Task { if let id = await store.respond(to: request.id, with: .accept) { router.openConversation(with: id) } }
    }

    private func stateBadge(_ state: RequestState) -> some View {
        let color: Color = switch state {
        case .pending: KizukiTheme.yellow
        case .accepted: KizukiTheme.blue
        default: KizukiTheme.babyBlueIcons
        }
        return Text(state == .declined ? "Not this time" : state == .ended ? "Left the Crew" : state.rawValue).font(KizukiTheme.mono(11))
            .padding(.horizontal, 10).padding(.vertical, 5).foregroundStyle(state == .accepted ? KizukiTheme.cream : KizukiTheme.charcoal)
            .background(color, in: Capsule())
    }

    // MARK: Create

    @ViewBuilder private var create: some View {
        VStack(spacing: 8) {
            HStack(spacing: -8) { PersonAvatar(FixtureAvatarIDs.a, size: 64); PersonAvatar(FixtureAvatarIDs.b, size: 64) }
            Text("Make room for your next idea.").font(KizukiTheme.title(26))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        chooser("Create a project", "Find a Crew for something new", "plus.rectangle.on.rectangle") { router.sheet = .createProject }
        chooser("Post a collab", "Share a glimpse of your process", "photo.on.rectangle") { router.sheet = .postCollab }
    }

    private func chooser(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title + " +").font(KizukiTheme.title(26))
                    Text(subtitle).font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
                }
                Spacer()
                Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(KizukiTheme.blue)
            }
            .frame(maxWidth: .infinity, minHeight: 78).kizukiPanel()
        }
        .buttonStyle(.plain)
    }
}

/// Identity has the full card width; actions share one centered trailing row.
struct CrewCard: View {
    let person: Person
    let onMessage: () -> Void
    let onProfile: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onMessage) {
                // Unlike PersonRow, Crew identity has no trailing glyph or subtitle line limit.
                HStack(spacing: 14) {
                    PersonAvatar(person.id, size: 48, portraitAsset: person.portraitAsset)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(KizukiTheme.bodyMedium(17))
                        Text("\(person.primaryRole) · Say hello")
                            .font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens chat")
            HStack(alignment: .center, spacing: 8) {
                Button("View profile", action: onProfile)
                    .font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
                    .accessibilityLabel("View profile for \(person.name)")
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 8) {
                    KizukiIconButton(icon: .messages, label: "Message \(person.name)", action: onMessage)
                        .accessibilityShowsLargeContentViewer()
                    Menu {
                        Button("Remove from Crew", systemImage: "person.badge.minus", role: .destructive, action: onRemove)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .foregroundStyle(KizukiTheme.babyBlueIcons)
                    .accessibilityLabel("More options for \(person.name)")
                    .accessibilityShowsLargeContentViewer()
                }
                .fixedSize()
            }
            .buttonStyle(.plain)
        }
        .kizukiPanel()
    }
}

/// The Suki creature in Kizuki orange (Figma App (Copy) `614:9214`), drawn from a template vector. Always decorative.
struct SukiMascotView: View {
    let height: CGFloat
    var body: some View {
        KizukiIcon.sukiMascot.image.resizable().scaledToFit().frame(height: height)
            .foregroundStyle(KizukiTheme.orange).accessibilityHidden(true)
    }
}

/// Empty state with Suki. The mascot is hidden from VoiceOver; the title and message are read as one element.
struct SukiEmptyState: View {
    let title: String
    let message: String
    var body: some View {
        KizukiEmptyState(title: title, message: message)
    }
}

enum FixtureAvatarIDs {
    static let a = UUID(uuidString: "00000000-0000-0001-0000-000000000003")!
    static let b = UUID(uuidString: "00000000-0000-0001-0000-000000000005")!
}

public struct RequestDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let requestID: UUID
    public init(requestID: UUID) { self.requestID = requestID }

    public var body: some View {
        if let request = store.request(requestID), let person = store.person(request.personID) {
            PageScroll(spacing: 18) {
                HStack(spacing: 14) {
                    PersonAvatar(person.id, size: 64, portraitAsset: person.portraitAsset)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(KizukiTheme.title(28))
                        Text("@\(person.handle) · \(person.city)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    }
                }
                Button("View profile") { router.push(.profile(person.id)) }.font(KizukiTheme.mono(12)).frame(minHeight: 44)
                VStack(alignment: .leading, spacing: 12) {
                    row("Type", request.kind.label)
                    if let project = request.projectID.flatMap(store.project) { row("Project", project.title) }
                    row("Role", request.role)
                    row("Time", request.timeCommitment)
                    row("Status", request.state.rawValue)
                    Text(request.note).font(KizukiTheme.body(16)).padding(.top, 6)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(KizukiTheme.grey.opacity(0.5), in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
                if request.state == .pending {
                    if request.direction == .incoming {
                        PrimaryButton("Accept and chat", color: KizukiTheme.blue) {
                            Task { if let id = await store.respond(to: request.id, with: .accept) { router.openConversation(with: id) } }
                        }
                        OutlineButton("Decline") { Task { await store.respond(to: request.id, with: .decline); router.pop() } }
                    } else {
                        OutlineButton("Withdraw request") { Task { await store.respond(to: request.id, with: .withdraw) } }
                    }
                } else if request.state == .accepted {
                    PrimaryButton("Open chat", color: KizukiTheme.blue) { router.push(.conversation(person.id)) }
                }
            }
            .navigationTitle(request.direction == .incoming ? "Request" : "Sent request").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report", systemImage: "flag") { router.sheet = .report(person.id) }
                        Button("Block", systemImage: "nosign", role: .destructive) { Task { await store.block(person.id); router.pop() } }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("More")
                }
            }
        } else {
            ContentUnavailableView("Request not found", systemImage: "tray")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons).frame(width: 70, alignment: .leading)
            Text(value).font(KizukiTheme.bodyMedium(15))
            Spacer()
        }
    }
}
#endif
