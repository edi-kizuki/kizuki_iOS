#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
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
        HStack(alignment: .center, spacing: 16) {
            PersonAvatar(person.id, size: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name).font(KizukiTheme.title(32))
                Text("@\(person.handle)").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                Text("\(person.primaryRole) · \(person.realm.rawValue)").font(KizukiTheme.body(14))
                Label(person.city, systemImage: "mappin.and.ellipse").font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
            Spacer()
        }
        if isMe {
            OutlineButton("Edit profile") { router.sheet = .editProfile }
            if store.discoveryDoneCount < store.discoverySteps.count { GetDiscoveredCard() }
        } else if store.isInCrew(person.id) {
            PrimaryButton("Open chat", color: KizukiTheme.blue) { router.push(.conversation(person.id)) }
        } else if let incoming = store.incomingPending(from: person.id) {
            PrimaryButton("Review their request", color: KizukiTheme.blue) { router.push(.request(incoming.id)) }
        } else {
            let pending = store.pendingRequest(for: person.id, project: nil) != nil
            PrimaryButton(pending ? "Wish sent" : "Wish to Collab", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) {
                router.sheet = .compose(personID: person.id, projectID: nil)
            }
            .disabled(pending)
        }
        if !person.bio.isEmpty { Text(person.bio).font(KizukiTheme.body(15)) }
        FlowLayout(spacing: 8) { ForEach(person.roles, id: \.self) { KizukiChip($0) } }
        // Availability is public on every profile (decision 51). Work mode and pay preference stay owner-only.
        let availability = isMe ? store.own.availability : person.availability
        VStack(alignment: .leading, spacing: 6) {
            Label(isMe ? "I’m available to collab" : "\(person.firstName) is available to collab", systemImage: "battery.75percent").font(KizukiTheme.bodyMedium(14))
            Text(availability.rawValue).font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            if isMe {
                Text("\(store.own.workMode.rawValue) · \(store.own.compensation.rawValue)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                Text("Everyone sees your availability. Only you see work mode and pay preference.").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(KizukiTheme.grey.opacity(0.5), in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
        .accessibilityElement(children: .combine)
        let favourites = isMe ? (store.own.showFavourites ? Array(store.own.favourites).sorted() : []) : person.favourites
        if !favourites.isEmpty {
            SectionTitle("Favourites")
            FlowLayout(spacing: 8) { ForEach(favourites, id: \.self) { KizukiChip($0) } }
        }
        if !person.links.isEmpty {
            SectionTitle("Work")
            ForEach(person.links.filter { $0.kind.isEmbed }) { EmbedCard(link: $0) }
            ForEach(person.links.filter { !$0.kind.isEmbed }) { link in
                HStack {
                    Image(systemName: link.kind.symbol).frame(width: 28)
                    VStack(alignment: .leading) { Text(link.kind.rawValue).font(KizukiTheme.bodyMedium(15)); Text("Opens outside Kizuki").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons) }
                    Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(KizukiTheme.babyBlueIcons)
                }
                .padding(14).frame(minHeight: 56).overlay(RoundedRectangle(cornerRadius: 10).stroke(KizukiTheme.babyBlueIcons.opacity(0.4), lineWidth: 1))
                .accessibilityElement(children: .combine).accessibilityLabel("\(link.kind.rawValue), opens outside Kizuki")
            }
        }
        let photos = store.visiblePhotos.filter { $0.authorID == person.id }
        SectionTitle("Collabs")
        if photos.isEmpty {
            Text(isMe ? "Post a collab from Suki > Create." : "No collab photos yet.").font(KizukiTheme.body(13)).foregroundStyle(KizukiTheme.babyBlueIcons)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(photos) { photo in
                    Button { router.push(.collabPhoto(photo.id)) } label: { Artwork(seed: photo.artSeed, height: 112).videoBadge(photo.durationLabel) }
                        .buttonStyle(.plain).accessibilityLabel(photo.isVideo ? "Short video, \(photo.durationLabel ?? ""): \(photo.caption)" : "Collab photo: \(photo.caption)")
                }
            }
        }
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
            Text("A fuller profile helps the right people find you and say yes.").font(KizukiTheme.body(13)).foregroundStyle(KizukiTheme.babyBlueIcons)
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
                .buttonStyle(.plain).allowsHitTesting(!step.done)
                .accessibilityLabel(step.done ? "\(step.title), done" : step.title)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(KizukiTheme.grey.opacity(0.5), in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: KizukiTheme.cardRadius).stroke(KizukiTheme.orange.opacity(0.7), lineWidth: 1))
    }

    private func open(_ step: AppStore.DiscoveryStep) {
        switch step.kind {
        case .collab: router.tab = .suki; router.sukiSection = .create
        default: router.sheet = .editProfile
        }
    }
}

/// Mock embedded player. The live app uses an allow-listed, locked WKWebView (concept 2.12).
struct EmbedCard: View {
    let link: ProfileLink
    @State private var playing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: link.kind == .youtube ? [KizukiTheme.ink, KizukiTheme.orange] : link.kind == .soundcloud ? [KizukiTheme.charcoal, KizukiTheme.blue] : [KizukiTheme.grey, KizukiTheme.yellow],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Button { playing.toggle() } label: {
                    Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 52)).foregroundStyle(KizukiTheme.cream)
                        .frame(width: 60, height: 60)
                }
                .accessibilityLabel(playing ? "Pause \(link.title)" : "Play \(link.title)")
            }
            .frame(height: 130)
            HStack {
                Image(systemName: link.kind.symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title).font(KizukiTheme.bodyMedium(14)).lineLimit(1)
                    Text("\(link.kind.rawValue) · embedded player (mock)").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
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
    public init() {}

    public var body: some View {
        PageScroll(spacing: 18) {
            KizukiField("Display name", text: $name)
            KizukiTextArea("Bio", text: $bio)
            KizukiField("City", text: $city)
            Text("Roles (up to three)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            FlowLayout(spacing: 8) {
                ForEach(store.me.realm.roleOptions, id: \.self) { role in
                    Button {
                        if roles.contains(role) { if roles.count > 1 { roles.removeAll { $0 == role } } } else if roles.count < 3 { roles.append(role) }
                    } label: { KizukiChip(role, selected: roles.contains(role)).frame(minHeight: 44) }.buttonStyle(.plain)
                }
            }
            Text("Availability").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(Availability.allCases, id: \.self) { a in ChoiceRow(a.rawValue, selected: availability == a) { availability = a } }
            Text("Compensation preference").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(Compensation.allCases, id: \.self) { c in ChoiceRow(c.rawValue, selected: compensation == c) { compensation = c } }
            PrimaryButton("Save") {
                store.updateOwn { $0.person.name = name; $0.person.bio = bio; $0.person.city = city; $0.person.roles = roles; $0.availability = availability; $0.compensation = compensation }
                router.sheet = nil
            }
        }
        .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { router.sheet = nil } } }
        .onAppear {
            name = store.me.name; bio = store.me.bio; city = store.me.city; roles = store.me.roles
            availability = store.own.availability; compensation = store.own.compensation
        }
    }
}
#endif
