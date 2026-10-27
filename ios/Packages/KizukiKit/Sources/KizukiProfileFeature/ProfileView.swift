#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let personID: UUID
    let embedsInTab: Bool
    @State private var confirmingRemoval = false

    /// `embedsInTab` is true for the Profile tab root (shows the top bar), false when pushed.
    public init(personID: UUID, embedsInTab: Bool = false) { self.personID = personID; self.embedsInTab = embedsInTab }

    public var body: some View {
        let isMe = personID == store.me.id
        VStack(spacing: 0) {
            if embedsInTab { KizukiTopBar(title: "Profile", onSettings: { router.push(.settings) }, onInbox: { router.push(.inbox) }) }
            if let person = store.person(personID), isMe || !store.isBlocked(personID) {
                PageScroll(spacing: 20) { content(person, isMe: isMe) }
                    .navigationTitle(isMe ? "" : person.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if !isMe {
                            ToolbarItem(placement: .topBarTrailing) {
                                Menu {
                                    Button("Report", systemImage: "flag") { router.sheet = .report(personID) }
                                    if store.isInCrew(personID) {
                                        Button("Remove from Crew", systemImage: "person.badge.minus", role: .destructive) { confirmingRemoval = true }
                                    }
                                    Button("Block", systemImage: "nosign", role: .destructive) { Task { await store.block(personID); router.pop() } }
                                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("More")
                            }
                        }
                    }
            } else {
                ContentUnavailableView("Profile unavailable", systemImage: "person.slash").frame(maxHeight: .infinity)
            }
        }
        .background(KizukiTheme.charcoal)
        .removeFromCrewConfirmation(isPresented: $confirmingRemoval, name: store.person(personID)?.firstName ?? "this person") {
            Task { await store.removeFromCrew(personID) }
        }
    }

    @ViewBuilder private func content(_ person: Person, isMe: Bool) -> some View {
        KizukiPatternBackground(tint: coverAccent(person.id))
            .frame(height: 184)
            .background(KizukiTheme.darkGrey)
            .overlay { LinearGradient(colors: [.clear, KizukiTheme.charcoal], startPoint: .top, endPoint: .bottom) }
            .padding(.horizontal, -20).padding(.top, -20).padding(.bottom, -44)
            .accessibilityHidden(true)
        let identityLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        identityLayout {
            PersonAvatar(person.id, size: 92, portraitAsset: person.portraitAsset)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name).font(KizukiTheme.poppins(16, weight: .bold, relativeTo: .headline))
                Text("@\(person.handle)").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                if person.portraitAsset != nil { Text("Demo profile · stock portrait").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons) }
                Text(person.acceptsCollaboration ? "\(person.primaryRole) · \(person.realm.rawValue)" : "Here for inspiration").font(KizukiTheme.body(14))
                Label(person.city, systemImage: "mappin.and.ellipse").font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
            Spacer()
        }
        if isMe {
            OutlineButton("Edit profile") { router.sheet = .editProfile }
            if !store.isProfileComplete { GetDiscoveredCard() }
        } else if store.isInCrew(person.id) {
            PrimaryButton("Open chat", color: KizukiTheme.blue) { router.push(.conversation(person.id)) }
        } else if let incoming = store.incomingPending(from: person.id) {
            PrimaryButton("Review their request", color: KizukiTheme.blue) { router.push(.request(incoming.id)) }
        } else if person.acceptsCollaboration {
            let pending = store.pendingRequest(for: person.id, project: nil) != nil
            PrimaryButton(pending ? "Wish sent" : "Wish to Collab", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) {
                router.sheet = .compose(personID: person.id, projectID: nil)
            }
            .disabled(pending)
        }
        if !person.bio.isEmpty { Text(person.bio).font(KizukiTheme.poppins(15)) }
        FlowLayout(spacing: 8) { ForEach(person.roles, id: \.self) { role in KizukiChip("\(role) · \(person.roles.first == role ? "Main" : "Secondary")") } }
        // Availability is public on every profile (decision 51). Work mode and pay preference stay owner-only.
        if person.acceptsCollaboration {
        let availability = isMe ? store.own.availability : person.availability
        VStack(alignment: .leading, spacing: 6) {
            Label(isMe ? "I’m available to collab" : "\(person.firstName) is available to collab", systemImage: "battery.75percent").font(KizukiTheme.bodyMedium(14))
            Text(availability.rawValue).font(KizukiTheme.monoMedium(12)).tracking(-0.36).foregroundStyle(KizukiTheme.babyBlueIcons)
            if isMe {
                Text("\(store.own.workMode.rawValue) · \(store.own.compensation.rawValue)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                Text("Everyone sees your availability. Only you see work mode and pay preference.").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).kizukiPanel()
        .accessibilityElement(children: .combine)
        }
        let favourites = isMe ? (store.own.showFavourites ? Array(store.own.favourites).sorted() : []) : person.favourites
        if !favourites.isEmpty {
            SectionTitle("Favourites")
            FlowLayout(spacing: 8) { ForEach(favourites, id: \.self) { KizukiChip($0) } }
        }
        if !person.visibleLinks.isEmpty {
            SectionTitle("Work")
            ForEach(person.visibleLinks) { EmbedCard(link: $0) }
        }
        let photos = store.visiblePhotos.filter { $0.authorID == person.id }
        SectionTitle("Collabs")
        if photos.isEmpty {
            KizukiEmptyState(title: "No collabs yet", message: isMe ? "Share your process from Suki > Create whenever you’re ready." : "Their creative process will appear here.")
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(photos) { photo in
                    Button { router.push(.collabPhoto(photo.id)) } label: { Artwork(seed: photo.artSeed, height: 112).videoBadge(photo.durationLabel) }
                        .buttonStyle(.plain).accessibilityLabel(photo.isVideo ? "Short video, \(photo.durationLabel ?? ""): \(photo.caption)" : "Collab photo: \(photo.caption)")
                }
            }
        }
    }

    private func coverAccent(_ id: UUID) -> Color {
        let palette = [KizukiTheme.orange, KizukiTheme.blue, KizukiTheme.yellow, KizukiTheme.salmon, KizukiTheme.babyBlue]
        let index = id.uuidString.utf8.reduce(0) { ($0 * 31 + Int($1)) % palette.count }
        return palette[index].opacity(0.65)
    }
}

/// "Get discovered" (decision 57): a checklist on the own Profile that turns profile gaps into one-tap next steps.
/// Placed here, not in onboarding (already 12 steps) or Home (the recommendations stay the hero). Hidden at 100%.
struct GetDiscoveredCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let steps = store.discoverySteps
        let done = store.discoveryDoneCount
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Get discovered").font(KizukiTheme.title(26))
                Spacer()
                Text("\(done) of \(steps.count)").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.charcoal)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(KizukiTheme.yellow, in: Capsule())
            }
            Text("Finish your basics so people know who you are. Work links, favourites and collab posts are optional.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ProgressView(value: Double(done), total: Double(steps.count)).tint(KizukiTheme.orange).accessibilityHidden(true)
            ForEach(steps) { step in
                Button { open(step) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle").foregroundStyle(step.done ? KizukiTheme.orange : KizukiTheme.babyBlueIcons)
                        Text(step.title).font(KizukiTheme.bodyMedium(14))
                            .foregroundStyle(step.done ? KizukiTheme.babyBlueIcons : KizukiTheme.cream)
                        Spacer()
                        if !step.done { Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(KizukiTheme.babyBlueIcons) }
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(step.done)
                .accessibilityLabel(step.done ? "\(step.title), done" : step.title)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(KizukiTheme.surface, in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: KizukiTheme.cardRadius).stroke(KizukiTheme.orange.opacity(0.7), lineWidth: 1))
    }

    private func open(_ step: AppStore.DiscoveryStep) {
        router.sheet = .editProfile
    }
}

/// Validated portfolio destination; external links until consent-gated players are integrated.
struct EmbedCard: View {
    let link: ProfileLink
    var body: some View {
        let descriptor = PortfolioWidgetDescriptor(link: link)
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: link.kind == .youtube ? [KizukiTheme.ink, KizukiTheme.orange] : link.kind == .soundcloud ? [KizukiTheme.charcoal, KizukiTheme.blue] : [KizukiTheme.grey, KizukiTheme.yellow],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: link.kind.symbol).font(.system(size: 40)).foregroundStyle(KizukiTheme.cream)
            }
            .frame(height: 130)
            HStack {
                Image(systemName: link.kind.symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title).font(KizukiTheme.bodyMedium(14)).lineLimit(1)
                    Text(descriptor.state == .invalid ? "Demo link · not connected" : "\(link.kind.rawValue) · opens externally").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    if let url = descriptor.externalURL {
                        Link("Open on \(link.kind.rawValue)", destination: url).frame(minHeight: 44)
                    }
                    if descriptor.requiresPlaybackConsent {
                        Text("In-app playback is not connected yet. Nothing loads automatically.").font(KizukiTheme.body(12))
                    }
                }
                Spacer()
            }
            .padding(12).background(KizukiTheme.grey)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

public struct EditProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var name = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var roles: [String] = []
    @State private var availability: Availability = .mid
    @State private var compensation: Compensation = .open
    @State private var goal: Goal = .collaborate
    @State private var linkURLs: [LinkKind: String] = [:]
    @State private var enabledWidgets: Set<LinkKind> = []
    @State private var saving = false
    @State private var saveFailed = false
    public init() {}

    public var body: some View {
        PageScroll(spacing: 18) {
            PersonAvatar(store.me.id, size: 72, portraitAsset: store.me.portraitAsset).frame(maxWidth: .infinity)
            Text("Your profile basics").font(KizukiTheme.title(26))
            Text("Add your name, a bio of at least 10 characters, your city and roles. You can save your progress at any time.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
            KizukiField("Display name", text: $name)
            KizukiTextArea("Bio", text: $bio)
            KizukiField("City", text: $city)
            Text("I’m here to").font(KizukiTheme.title(22))
            ForEach(Goal.allCases, id: \.self) { option in
                ChoiceRow(option.rawValue, selected: goal == option) {
                    goal = option
                    if goal == .collaborate && roles.isEmpty { roles = [store.me.realm.roleOptions[0]] }
                }
            }
            if goal == .collaborate {
            Text("Roles: one main, up to three secondary").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            FlowLayout(spacing: 8) {
                ForEach(store.me.realm.roleOptions, id: \.self) { role in
                    Button {
                        roles = RoleSelection.toggling(role, in: roles, realm: store.me.realm)
                    } label: { KizukiChip(role, selected: roles.contains(role)).frame(minHeight: 44) }.buttonStyle(.plain)
                        .accessibilityValue(roles.first == role ? "Main" : roles.contains(role) ? "Secondary" : "Not selected")
                }
            }
            ForEach(roles, id: \.self) { role in
                HStack {
                    Text("\(role) · \(roles.first == role ? "Main" : "Secondary")").font(KizukiTheme.body(14)).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if roles.first != role {
                        Button("Make main") { roles = RoleSelection.promoting(role, in: roles) }
                            .accessibilityLabel("Make \(role) main").frame(minHeight: 44)
                    }
                }
            }
            Text("Availability").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(Availability.allCases, id: \.self) { a in ChoiceRow(a.rawValue, selected: availability == a) { availability = a } }
            Text("Compensation preference").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(Compensation.allCases, id: \.self) { c in ChoiceRow(c.rawValue, selected: compensation == c) { compensation = c } }
            }
            Text("Portfolio widgets").font(KizukiTheme.title(22))
            Text("All widgets are optional. Turn one off to hide it without deleting its link. Links open externally for now and are not used for matching.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(LinkKind.allCases, id: \.self) { kind in
                Toggle("Show \(kind.rawValue) widget", isOn: Binding(get: { enabledWidgets.contains(kind) }, set: { enabled in
                    if enabled { enabledWidgets.insert(kind) } else { enabledWidgets.remove(kind) }
                })).tint(KizukiTheme.orange)
                if enabledWidgets.contains(kind) || !(linkURLs[kind] ?? "").isEmpty {
                    KizukiField(kind.rawValue, text: Binding(get: { linkURLs[kind] ?? "" }, set: { linkURLs[kind] = $0 }), prompt: "https://…")
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            if !validLinks { Text("Add an HTTPS link from the named platform, or turn off empty widgets. To remove a saved link, turn its widget off and clear the field.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.salmon) }
        }
        .disabled(saving)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if saving { ProgressView("Saving profile").tint(KizukiTheme.cream) }
                if saveFailed { Text("Couldn’t save your profile. Please try again.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.salmon) }
                PrimaryButton("Save") {
                    saving = true
                    saveFailed = false
                    Task {
                        let saved = await store.saveProfileBasics(name: name, bio: bio, city: city, roles: roles, availability: availability, compensation: compensation, goal: goal, links: editedLinks)
                        saving = false
                        if saved { router.sheet = nil } else { saveFailed = true }
                    }
                }
                .disabled(saving || !validLinks)
            }
            .padding(KizukiTheme.pageInset).background(KizukiTheme.charcoal)
        }
        .interactiveDismissDisabled(saving)
        .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { router.sheet = nil }.disabled(saving) } }
        .onAppear {
            name = store.me.name; bio = store.me.bio; city = store.me.city; roles = store.me.roles
            availability = store.own.availability; compensation = store.own.compensation
            goal = store.own.goal
            linkURLs = Dictionary(uniqueKeysWithValues: store.me.links.map { ($0.kind, $0.url) })
            enabledWidgets = Set(store.me.visibleLinks.map(\.kind))
        }
    }

    private var editedLinks: [ProfileLink] {
        LinkKind.allCases.compactMap { kind in
            let url = (linkURLs[kind] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return nil }
            let title = store.me.links.first(where: { $0.kind == kind && $0.url == url })?.title ?? kind.rawValue
            return ProfileLink(kind: kind, title: title, url: url, isEnabled: enabledWidgets.contains(kind))
        }
    }
    private var validLinks: Bool {
        enabledWidgets.allSatisfy { !(linkURLs[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && editedLinks.allSatisfy { link in
                store.me.links.contains { $0.kind == link.kind && $0.url == link.url } || PortfolioWidgetDescriptor(link: link).state != .invalid
            }
    }
}
#endif
