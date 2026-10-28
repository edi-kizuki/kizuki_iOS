#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI
import PhotosUI
import CoreTransferable
import ImageIO
import UniformTypeIdentifiers

public struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let personID: UUID
    let embedsInTab: Bool
    @State private var confirmingRemoval = false

    public init(personID: UUID, embedsInTab: Bool = false) { self.personID = personID; self.embedsInTab = embedsInTab }

    public var body: some View {
        let isMe = personID == store.me.id
        VStack(spacing: 0) {
            if let person = store.person(personID), isMe || !store.isBlocked(personID) {
                GeometryReader { geometry in
                    PageScroll(spacing: 0, horizontalPadding: 0, verticalPadding: 0) {
                        cover(person, showsSettings: isMe && embedsInTab, topInset: geometry.safeAreaInsets.top)
                        VStack(alignment: .leading, spacing: 20) {
                            content(person, isMe: isMe)
                        }
                        .padding(.horizontal, KizukiTheme.pageInset)
                        .padding(.top, -24)
                        .padding(.bottom, KizukiTheme.pageInset)
                    }
                    .contentMargins(.top, 0, for: .scrollContent)
                    .ignoresSafeArea(.container, edges: isMe && embedsInTab ? .top : [])
                    .accessibilityIdentifier("profile-scroll")
                }
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

    private func cover(_ person: Person, showsSettings: Bool, topInset: CGFloat) -> some View {
        ProfileCoverImage(data: person.coverData, tint: coverAccent(person.id))
            .frame(height: 184)
            .background(KizukiTheme.darkGrey)
            .overlay {
                if person.coverData != nil {
                    LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0.35),
                        .init(color: .black.opacity(0.2), location: 0.6), .init(color: KizukiTheme.charcoal, location: 1)],
                        startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: [.clear, KizukiTheme.charcoal], startPoint: .top, endPoint: .bottom)
                }
            }
            .accessibilityHidden(true)
            .overlay(alignment: .topTrailing) {
                if showsSettings {
                    KizukiIconButton(symbol: "line.3.horizontal", label: "Settings") { router.push(.settings) }
                        .background(KizukiTheme.charcoal.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHint("Opens your profile settings")
                        .padding(.top, topInset + 8)
                        .padding(.trailing, KizukiTheme.pageInset)
                }
            }
    }

    @ViewBuilder private func content(_ person: Person, isMe: Bool) -> some View {
        let identityLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        identityLayout {
            PersonAvatar(person.id, size: 92, portraitAsset: person.portraitAsset, portraitData: person.portraitData)
                .accessibilityLabel(person.portraitData == nil ? "Profile avatar" : "Profile picture")
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name).font(KizukiTheme.poppins(16, weight: .bold, relativeTo: .headline))
                Text("@\(person.handle)").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                if person.portraitAsset != nil { Text("Demo profile · stock portrait").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons) }
                Text(person.acceptsCollaboration ? "\(person.primaryRole) · \(person.realm.rawValue)" : "Here for inspiration").font(KizukiTheme.body(14))
                Label(person.city, systemImage: "mappin.and.ellipse").font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-identity")
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                AvailabilityBattery(level: availability.level)
                Text(isMe ? "I’m available to collab" : "\(person.firstName) is available to collab").font(KizukiTheme.bodyMedium(14))
            }
            Text("\(availability.levelLabel) · \(availability.hoursLabel)").font(KizukiTheme.monoMedium(12)).tracking(-0.36).foregroundStyle(KizukiTheme.cream)
            if isMe {
                Text("\(store.own.workMode.rawValue) · \(store.own.compensation.rawValue)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                Text("Everyone sees your availability. Only you see work mode and pay preference.").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).kizukiFloatingCard(padding: KizukiTheme.cardInset)
        .padding(.horizontal, KizukiTheme.floatingCardInset - KizukiTheme.pageInset)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile-availability")
        }
        if !person.visibleLinks.isEmpty {
            SectionTitle("Portfolio")
            ForEach(person.visibleLinks) { EmbedCard(link: $0).padding(.horizontal, KizukiTheme.floatingCardInset - KizukiTheme.pageInset) }
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
            .padding(.horizontal, -20)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let steps = store.discoverySteps
        let done = store.discoveryDoneCount
        VStack(alignment: .leading, spacing: 12) {
            let headingLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
            headingLayout {
                Text("Get discovered").font(KizukiTheme.title(26))
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("\(done) of \(steps.count)").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.charcoal)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(KizukiTheme.yellow, in: Capsule())
            }
            Text("Finish your basics so people know who you are. Portfolio links and collab posts are optional.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
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

struct AvailabilityBattery: View {
    let level: Availability.Level
    var body: some View {
        let (symbol, color): (String, Color) = switch level {
        case .low: ("battery.25percent", KizukiTheme.availabilityLow)
        case .medium: ("battery.50percent", KizukiTheme.availabilityMedium)
        case .high: ("battery.100percent", KizukiTheme.availabilityHigh)
        }
        Image(systemName: symbol)
            .symbolRenderingMode(.palette)
            .foregroundStyle(color, KizukiTheme.cream)
            .font(.system(size: 18, weight: .medium))
            .accessibilityHidden(true)
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
                ProviderIcon(link.kind.iconAsset, size: 48).foregroundStyle(KizukiTheme.cream)
            }
            .frame(height: 130)
            HStack {
                ProviderIcon(link.kind.iconAsset)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title).font(KizukiTheme.bodyMedium(14)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Text(descriptor.state == .invalid ? "Demo link · not connected" : "\(link.kind.rawValue) · opens externally").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    if let url = descriptor.externalURL {
                        Link(destination: url) { Text("Open on \(link.kind.rawValue)").frame(minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
                    }
                    if descriptor.requiresPlaybackConsent {
                        Text("In-app playback is not connected yet. Nothing loads automatically.").font(KizukiTheme.body(12))
                    }
                }
                Spacer()
            }
            .padding(KizukiTheme.cardInset).background(KizukiTheme.grey)
        }
        .kizukiFloatingCard(padding: 0, fill: KizukiTheme.grey)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-work-\(link.kind.rawValue)")
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
    @State private var editingWidget: LinkKind?
    @State private var loadedDraft = false
    @State private var saving = false
    @State private var saveFailed = false
    @State private var portraitSelection: PhotosPickerItem?
    @State private var coverSelection: PhotosPickerItem?
    @State private var portraitData: Data?
    @State private var coverData: Data?
    @State private var portraitChanged = false
    @State private var coverChanged = false
    @State private var portraitLoading = false
    @State private var coverLoading = false
    @State private var photoError: String?
    public init() {}

    public var body: some View {
        PageScroll(spacing: 18) {
            photoEditor
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
            ForEach(Availability.allCases, id: \.self) { a in ChoiceRow(a.hoursLabel, selected: availability == a, detail: a.levelLabel) { availability = a } }
            Text("Compensation preference").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(Compensation.allCases, id: \.self) { c in ChoiceRow(c.rawValue, selected: compensation == c) { compensation = c } }
            }
            Text("Portfolio").font(KizukiTheme.title(22)).accessibilityIdentifier("edit-profile-portfolio")
            Text("Your work, in one place. Add a link, then choose what appears on your profile. Nothing here is used for matching.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ForEach(LinkKind.allCases, id: \.self) { kind in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ProviderIcon(kind.iconAsset, size: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.rawValue).font(KizukiTheme.bodyMedium(16))
                            Text(widgetStatus(kind)).font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                        }
                        Spacer(minLength: 8)
                        Button((linkURLs[kind] ?? "").isEmpty ? "Connect" : "Edit") { editingWidget = kind }
                            .font(KizukiTheme.bodyMedium(14)).frame(minHeight: 44)
                            .accessibilityLabel("\((linkURLs[kind] ?? "").isEmpty ? "Connect" : "Edit") \(kind.rawValue)")
                    }
                    if !(linkURLs[kind] ?? "").isEmpty {
                        Toggle("Show on profile", isOn: Binding(get: { enabledWidgets.contains(kind) }, set: { enabled in
                            if enabled { enabledWidgets.insert(kind) } else { enabledWidgets.remove(kind) }
                        })).tint(KizukiTheme.orange).font(KizukiTheme.body(14))
                            .accessibilityLabel("Show \(kind.rawValue) on profile")
                    }
                }
                .padding(16).background(KizukiTheme.grey, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .disabled(saving || loadingPhotos)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if saving { ProgressView("Saving profile").tint(KizukiTheme.cream) }
                if saveFailed { Text("Couldn’t save your profile. Please try again.").font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.salmon) }
                PrimaryButton("Save") {
                    saving = true
                    saveFailed = false
                    Task {
                        let saved = await store.saveProfileBasics(name: name, bio: bio, city: city, roles: roles, availability: availability, compensation: compensation, goal: goal, links: editedLinks,
                            portrait: portraitChanged ? portraitData.map(ProfilePhotoUpdate.replace) ?? .remove : .unchanged,
                            cover: coverChanged ? coverData.map(ProfilePhotoUpdate.replace) ?? .remove : .unchanged)
                        saving = false
                        if saved { router.sheet = nil } else { saveFailed = true }
                    }
                }
                .disabled(saving || loadingPhotos)
            }
            .padding(KizukiTheme.pageInset).background(KizukiTheme.charcoal)
        }
        .interactiveDismissDisabled(saving)
        .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { router.sheet = nil }.disabled(saving) } }
        .sheet(isPresented: Binding(get: { editingWidget != nil }, set: { if !$0 { editingWidget = nil } })) {
            if let kind = editingWidget {
                PortfolioConnectionSheet(kind: kind, savedURL: linkURLs[kind] ?? "") { url in
                    let isNew = (linkURLs[kind] ?? "").isEmpty
                    linkURLs[kind] = url
                    if url.isEmpty { enabledWidgets.remove(kind) }
                    else if isNew { enabledWidgets.insert(kind) }
                    editingWidget = nil
                }
            }
        }
        .onAppear {
            guard !loadedDraft else { return }
            loadedDraft = true
            name = store.me.name; bio = store.me.bio; city = store.me.city; roles = store.me.roles
            availability = store.own.availability; compensation = store.own.compensation
            goal = store.own.goal
            linkURLs = Dictionary(uniqueKeysWithValues: store.me.links.map { ($0.kind, $0.url) })
            enabledWidgets = Set(store.me.visibleLinks.map(\.kind))
            portraitData = store.me.portraitData
            coverData = store.me.coverData
        }
        .task(id: portraitSelection) { await importPhoto(portraitSelection, isCover: false) }
        .task(id: coverSelection) { await importPhoto(coverSelection, isCover: true) }
    }

    private var loadingPhotos: Bool { portraitLoading || coverLoading }

    private var photoEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileCoverImage(data: coverData, tint: KizukiTheme.yellow.opacity(0.65))
                .frame(height: 140).clipShape(RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
                .accessibilityLabel(coverData == nil ? "Default cover" : "Cover photo preview")
            HStack(alignment: .center, spacing: 16) {
                PersonAvatar(store.me.id, size: 72, portraitAsset: portraitChanged ? nil : store.me.portraitAsset, portraitData: portraitData)
                    .accessibilityLabel(portraitData == nil ? "Profile avatar preview" : "Profile picture preview")
                VStack(alignment: .leading, spacing: 0) {
                    PhotosPicker(selection: $portraitSelection, matching: .images, preferredItemEncoding: .compatible) {
                        Label("Change profile picture", systemImage: "camera").frame(minHeight: 44, alignment: .leading)
                    }.accessibilityIdentifier("change-profile-picture")
                    if portraitData != nil || (!portraitChanged && store.me.portraitAsset != nil) {
                        Button("Remove profile picture", role: .destructive) {
                            portraitData = nil; portraitChanged = true; portraitSelection = nil
                        }.frame(minHeight: 44).accessibilityIdentifier("remove-profile-picture")
                    }
                }
            }
            PhotosPicker(selection: $coverSelection, matching: .images, preferredItemEncoding: .compatible) {
                Label("Change cover photo", systemImage: "photo").frame(minHeight: 44, alignment: .leading)
            }.accessibilityIdentifier("change-cover-photo")
            if coverData != nil {
                Button("Remove cover photo", role: .destructive) {
                    coverData = nil; coverChanged = true; coverSelection = nil
                }.frame(minHeight: 44).accessibilityIdentifier("remove-cover-photo")
            }
            if loadingPhotos { ProgressView("Preparing photo…").tint(KizukiTheme.cream) }
            if let photoError { Text(photoError).foregroundStyle(KizukiTheme.salmon).accessibilityIdentifier("profile-photo-error") }
            Text("Photos stay on this device in this preview. Cloud upload is not connected yet.")
                .font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
        }
        .font(KizukiTheme.body(14)).tint(KizukiTheme.cream)
    }

    private func importPhoto(_ selection: PhotosPickerItem?, isCover: Bool) async {
        guard let selection else { return }
        if isCover { coverLoading = true } else { portraitLoading = true }
        photoError = nil
        defer { if isCover { coverLoading = false } else { portraitLoading = false } }
        do {
            guard let imported = try await selection.loadTransferable(type: ImportedProfilePhoto.self) else {
                throw ProfilePhotoProcessor.Failure.unreadable
            }
            let data = try await Task.detached(priority: .userInitiated) {
                if isCover { return imported.data }
                return try ProfilePhotoProcessor.prepare(data: imported.data, maximumDimension: 512)
            }.value
            try Task.checkCancellation()
            if isCover { coverData = data; coverChanged = true }
            else { portraitData = data; portraitChanged = true }
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            photoError = "Couldn’t load that photo. Choose another still image under 25 MB, or download it from iCloud and try again."
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
    private func widgetStatus(_ kind: LinkKind) -> String {
        guard let url = linkURLs[kind], !url.isEmpty else { return "Optional · no link added" }
        guard PortfolioWidgetDescriptor(link: ProfileLink(kind: kind, title: kind.rawValue, url: url)).state != .invalid else { return "Demo link · replace with your work" }
        return enabledWidgets.contains(kind) ? "Link added · shown on profile" : "Link added · hidden from profile"
    }
}

private struct ProfileCoverImage: View {
    let data: Data?
    let tint: Color
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                KizukiPatternBackground(tint: tint)
            }
        }.clipped()
    }
}

private struct ImportedProfilePhoto: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            ImportedProfilePhoto(data: try ProfilePhotoProcessor.prepare(file: received.file))
        }
    }
}

public enum ProfilePhotoProcessor {
    public enum Failure: Error { case unreadable, tooLarge }
    public static let maximumInputBytes = 25_000_000

    public static func prepare(file: URL) throws -> Data {
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumInputBytes else { throw Failure.tooLarge }
        guard let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw Failure.unreadable }
        return try prepare(source: source, maximumDimension: 1600)
    }

    public static func prepare(data: Data, maximumDimension: Int = 1600) throws -> Data {
        guard !data.isEmpty, data.count <= maximumInputBytes else { throw Failure.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw Failure.unreadable }
        return try prepare(source: source, maximumDimension: maximumDimension)
    }

    private static func prepare(source: CGImageSource, maximumDimension: Int) throws -> Data {
        guard (1...1600).contains(maximumDimension), CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 20_000, height <= 20_000,
              width * height <= 100_000_000 else { throw Failure.unreadable }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw Failure.unreadable }
        for quality in [0.82, 0.65, 0.45] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw Failure.unreadable }
            CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw Failure.unreadable }
            if output.length <= ProfilePhotoUpdate.maximumBytes { return output as Data }
        }
        throw Failure.tooLarge
    }
}

private struct PortfolioConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LinkKind
    let savedURL: String
    let apply: (String) -> Void
    @State private var url: String
    @State private var attemptedSave = false

    init(kind: LinkKind, savedURL: String, apply: @escaping (String) -> Void) {
        self.kind = kind
        self.savedURL = savedURL
        self.apply = apply
        _url = State(initialValue: savedURL)
    }

    var body: some View {
        NavigationStack {
            PageScroll(spacing: 20) {
                ProviderIcon(kind.iconAsset, size: 48).frame(maxWidth: .infinity)
                Text("Bring your \(kind.rawValue) work along").font(KizukiTheme.title(26))
                Text("Account sign-in isn’t available in this build. Add a public link instead. This does not authorize access to your account.")
                    .font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
                KizukiField(kind.rawValue, text: $url, prompt: kind.exampleURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: url) { _, _ in attemptedSave = false }
                Text("Paste a profile or work link. We’ll add https:// if needed. Links open externally; nothing loads automatically.")
                    .font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                if attemptedSave {
                    Text("Use a public \(kind.rawValue) link, such as \(kind.exampleURL).")
                        .font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.salmon)
                        .accessibilityIdentifier("widget-url-error")
                }
                if !savedURL.isEmpty {
                    Button("Remove link", role: .destructive) { apply("") }.frame(minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Use link") {
                    if let normalized = kind.normalizedPortfolioURL(url) { apply(normalized) }
                    else { attemptedSave = true }
                }.padding(KizukiTheme.pageInset).background(KizukiTheme.charcoal)
            }
            .navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}
#endif
