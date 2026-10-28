#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

/// Privacy-relevant onboarding copy, kept in one place so a unit test can pin it to the locked decisions.
public enum OnboardingCopy {
    /// Decision 51: availability is public on every profile. Work mode and pay preference stay owner-only.
    public static let availability = "Everyone sees your availability on your profile. Only you see your work mode and pay preference. Change it whenever life changes."
}

/// Screens of the entry and onboarding flow. Raw values double as launch-argument screen ids.
public enum EntryScreen: Hashable, Sendable {
    case splash, login, eligibility
    case step(OnboardingStep)
}

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case handle, goal, realm, roles, taste, favourites, compensation, availability, city, notifications, location
    public var id: String {
        ["handle", "goal", "realm", "roles", "taste", "favourites", "compensation", "availability", "city", "primer-notifications", "primer-location"][rawValue]
    }
    public static func steps(for goal: Goal) -> [Self] {
        allCases.filter { goal == .collaborate || ![Self.roles, .compensation, .availability].contains($0) }
    }
    var isPrimer: Bool { self == .notifications || self == .location }
}

public extension EntryScreen {
    var id: String {
        switch self {
        case .splash: "splash"
        case .login: "login"
        case .eligibility: "eligibility"
        case let .step(step): "onb-\(step.id)"
        }
    }
    static var all: [EntryScreen] { [.splash, .login, .eligibility] + OnboardingStep.allCases.map { .step($0) } }
    init?(id: String) {
        guard let match = Self.all.first(where: { $0.id == id }) else { return nil }
        self = match
    }
}

/// Splash → sign-in (stubs) → 18+ and Terms → onboarding. No network calls anywhere.
public struct EntryFlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var screen: EntryScreen
    @State private var draft: OwnProfile
    @State private var emailEntry = false
    @State private var email = "mika@example.com"
    @State private var password = "prototype"
    @State private var ageAndTerms = false
    @State private var showTerms = false
    @State private var search = ""
    @State private var saving = false
    @State private var saveFailed = false
    let onFinish: (OwnProfile) async -> Bool
    let autoAdvanceSplash: Bool

    public init(start: EntryScreen = .splash, autoAdvanceSplash: Bool = true, initial: OwnProfile, onFinish: @escaping (OwnProfile) async -> Bool) {
        _screen = State(initialValue: start)
        _draft = State(initialValue: initial)
        self.onFinish = onFinish
        self.autoAdvanceSplash = autoAdvanceSplash
    }

    private let titles = ["What should we call you?", "What are you looking to do?", "Find your creative realm", "What’s your role?",
                          "What catches your eye?", "Your favourites, your world", "What kind of work?", "How much time do you have?",
                          "Where do you create?", "Stay in the loop", "Find your nearby people"]
    private var steps: [OnboardingStep] { OnboardingStep.steps(for: draft.goal) }

    public var body: some View {
        Group {
            switch screen {
            case .splash: splash
            case .login: login
            case .eligibility: eligibility
            case let .step(step): stepScreen(step)
            }
        }
        .background {
            if screen == .splash {
                Color(hex: 0xFF6139).overlay { onboardingPattern(tint: Color(hex: 0xFF4B1E)) }.ignoresSafeArea()
            } else {
                Color(hex: 0x0F0F0F).overlay { onboardingPattern(tint: KizukiTheme.charcoal) }.ignoresSafeArea()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: screen)
        .foregroundStyle(KizukiTheme.cream)
        .task(id: screen) {
            if screen == .splash, autoAdvanceSplash {
                do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
                if screen == .splash { screen = .login }
            }
        }
        .sheet(isPresented: $showTerms) { termsSheet }
    }

    // MARK: Entry

    private var splash: some View {
        VStack(spacing: 12) {
            Spacer()
            KizukiIcon.kMark.image.resizable().scaledToFit().frame(width: 100, height: 188).foregroundStyle(KizukiTheme.charcoal)
                .accessibilityLabel("Kizuki")
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .offset(y: -29)
        .accessibilityElement(children: .combine)
    }

    private var login: some View {
        GeometryReader { geometry in
        ScrollView {
        VStack(spacing: 0) {
            KizukiIllustration.onboardingTrio.originalImage.resizable().scaledToFit()
                .frame(maxWidth: 346).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: dynamicTypeSize.isAccessibilitySize || emailEntry ? 210 : 262, alignment: .top)
                .padding(.top, 38)
                .background(alignment: .topLeading) {
                    KizukiIllustration.onboardingLoginPattern.originalImage.resizable()
                        .frame(width: geometry.size.width * 467 / 393, height: geometry.size.width * 434 / 393)
                        .offset(x: -18, y: -geometry.safeAreaInsets.top - 45)
                }
                .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 20) {
            (Text("LET’S GET ") + Text("CREATIVE.").foregroundColor(KizukiTheme.orange))
                .font(KizukiTheme.title(36)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            Text("Find the people who have always been looking for you.")
                .font(KizukiTheme.poppins(14)).multilineTextAlignment(.center)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 253)
                .frame(maxWidth: .infinity).padding(.bottom, 16)
            if emailEntry {
                KizukiField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password").font(KizukiTheme.poppins(12, relativeTo: .caption)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    SecureField("Password", text: $password).font(KizukiTheme.poppins(15)).padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(KizukiTheme.cream.opacity(0.3)).frame(height: 0.6) }
                }
                PrimaryButton("Continue") { screen = .eligibility }
                Text("Prototype: any email works. Nothing is sent.").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            } else {
                Button { screen = .eligibility } label: {
                    Label("Sign in with Apple", systemImage: "apple.logo").font(KizukiTheme.bodyMedium(17))
                        .frame(maxWidth: .infinity, minHeight: 50).background(KizukiTheme.cream).foregroundStyle(KizukiTheme.charcoal)
                        .background(alignment: .topLeading) { Rectangle().fill(KizukiTheme.orange).offset(x: 4, y: 4) }
                }.buttonStyle(.plain).padding(.trailing, 4)
                PrimaryButton("Continue with email") { emailEntry = true }
            }
            Text("A space for film, music & visual arts.").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons).padding(.bottom, 16)
        }
        .padding(.horizontal, 32).padding(.top, 72).padding(.bottom, 32)
        .frame(minHeight: max(0, geometry.size.height - 300), alignment: .top)
        .background {
            KizukiIllustration.onboardingLoginPaper.originalImage
                .resizable(capInsets: EdgeInsets(top: 40, leading: 0, bottom: 0, trailing: 0))
        }
        }
        }
        .scrollDismissesKeyboard(.interactively)
        }
    }

    private func entryIllustration(height: CGFloat) -> some View {
        KizukiIllustration.dancingTrio.image.resizable().scaledToFit()
            .foregroundStyle(KizukiTheme.cream).padding(20)
            .frame(maxWidth: .infinity).frame(height: height)
            .background { KizukiPatternBackground(tint: KizukiTheme.orange) }
            .clipped().accessibilityHidden(true)
    }

    private var eligibility: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("GOOD PEOPLE.\nGOOD GROUND RULES.").font(KizukiTheme.title(40))
            Text("A creative community for adults. Let’s keep it thoughtful, safe and kind.").font(KizukiTheme.poppins(16)).foregroundStyle(KizukiTheme.babyBlueIcons)
            Button { ageAndTerms.toggle() } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: ageAndTerms ? "checkmark.square.fill" : "square").font(.system(size: 26))
                        .foregroundStyle(ageAndTerms ? KizukiTheme.orange : KizukiTheme.babyBlueIcons)
                    Text("I am 18 or older and agree to the Terms.").font(KizukiTheme.body(16)).multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(16).overlay(RoughShape().stroke(ageAndTerms ? KizukiTheme.orange : KizukiTheme.babyBlueIcons, lineWidth: 1.2))
            }
            .buttonStyle(.plain).accessibilityAddTraits(ageAndTerms ? .isSelected : [])
            Button("Read Terms, Community Guidelines & Privacy") { showTerms = true }
                .font(KizukiTheme.mono(13)).frame(minHeight: 44).foregroundStyle(KizukiTheme.babyBlue)
            Spacer()
            PrimaryButton("Continue") { screen = .step(.handle) }.disabled(!ageAndTerms)
        }
        .padding(28)
    }

    private var termsSheet: some View {
        NavigationStack {
            PageScroll {
                Text("Terms & community guidelines").font(KizukiTheme.title(30))
                Text("Be 18 or older. Respect the people you meet. Share only work you have permission to share.")
                Text("This is sample copy for the prototype. Full Terms and Privacy Policy need legal review before launch.").foregroundStyle(KizukiTheme.babyBlueIcons)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showTerms = false } } }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Onboarding

    private var validHandle: Bool { draft.person.handle.range(of: "^[a-z0-9._]{3,20}$", options: .regularExpression) != nil }

    private func stepScreen(_ step: OnboardingStep) -> some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            if !step.isPrimer {
                if step != .handle && !dynamicTypeSize.isAccessibilitySize { sukiTip.padding(.horizontal, 11).padding(.top, 4).padding(.bottom, 16) }
                HStack(spacing: 5) {
                    ForEach(Array(steps.enumerated()), id: \.element) { index, _ in
                        Capsule().fill(index <= (steps.firstIndex(of: step) ?? 0) ? KizukiTheme.orange : KizukiTheme.grey).frame(height: 4)
                    }
                }
                .padding(.horizontal, 13).padding(.top, step == .handle ? 14 : 0).accessibilityHidden(true)
                HStack {
                    Button { go(back: step) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous step")
                    Spacer()
                    Text("\((steps.firstIndex(of: step) ?? 0) + 1) / \(steps.count)").font(KizukiTheme.mono()).foregroundStyle(KizukiTheme.babyBlueIcons)
                }
                .padding(.horizontal, 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !step.isPrimer && step != .handle && dynamicTypeSize.isAccessibilitySize { sukiTip }
                    if step == .handle {
                        HStack(spacing: 20) {
                            Text("WELCOME!").font(KizukiTheme.title(36))
                            KizukiIllustration.onboardingAxolotl.image.resizable().scaledToFit().frame(width: 42, height: 36).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 58)
                    }
                    if step.isPrimer {
                        if step == .location {
                            entryIllustration(height: dynamicTypeSize.isAccessibilitySize ? 100 : 180)
                        } else {
                            KizukiIcon.sukiMascot.image.resizable().scaledToFit()
                                .frame(height: 100).foregroundStyle(KizukiTheme.orange)
                                .frame(maxWidth: .infinity).padding(.top, 24).accessibilityHidden(true)
                        }
                    }
                    Text((draft.goal == .explore && step == .realm ? "What worlds inspire you?" : titles[step.rawValue]).uppercased()).font(KizukiTheme.title(32)).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, step == .goal ? 30 : 10).accessibilityAddTraits(.isHeader)
                    content(step)
                }
                .padding(.horizontal, step == .goal ? 35 : 31).padding(.vertical, 12)
                .id(step).transition(.opacity)
            }
            .scrollDismissesKeyboard(.interactively)
            // Primers carry exactly one button (decision 31).
            PrimaryButton(step == steps.last ? (draft.goal == .explore ? "Start exploring" : "Enter Kizuki") : "Continue") { go(next: step) }
                .disabled(saving || (step == .handle && !validHandle) || (step == .roles && !RoleSelection.isValid(draft.person.roles, realm: draft.person.realm)))
                .padding(.horizontal, 56)
                .padding(.bottom, dynamicTypeSize.isAccessibilitySize || geometry.size.height < 600 ? 24 : 70).padding(.top, 8)
            if saveFailed { Text("Couldn’t save your profile. Please try again.").foregroundStyle(KizukiTheme.salmon) }
        }
        .background {
            if step != .handle {
                Color(hex: 0x0F0F0F).overlay { onboardingPattern(tint: KizukiTheme.charcoal) }.ignoresSafeArea()
            } else if step == .handle {
                VStack {
                    KizukiIllustration.onboardingWelcome.originalImage.resizable().frame(height: 219).rotationEffect(.degrees(180))
                    Spacer()
                }.ignoresSafeArea()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: draft.goal)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: draft.person.realm)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: draft.person.roles)
        .sensoryFeedback(.selection, trigger: draft.goal)
        .sensoryFeedback(.selection, trigger: draft.person.realm)
        .sensoryFeedback(.selection, trigger: draft.person.roles)
        }
    }

    private func go(next step: OnboardingStep) {
        if step == steps.last {
            saving = true
            Task {
                saveFailed = !(await onFinish(draft))
                saving = false
            }
        } else if let index = steps.firstIndex(of: step), steps.indices.contains(index + 1) { screen = .step(steps[index + 1]) }
    }
    private func go(back step: OnboardingStep) {
        if let index = steps.firstIndex(of: step), index > 0 { screen = .step(steps[index - 1]) } else { screen = .eligibility }
    }

    @ViewBuilder private func content(_ step: OnboardingStep) -> some View {
        switch step {
        case .handle:
            KizukiField("Display name", text: bind(\.person.name))
            KizukiField("Handle", text: bind(\.person.handle)).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text("3–20 lowercase letters, numbers, dots or underscores.").font(KizukiTheme.poppins(12, relativeTo: .caption))
                .foregroundStyle(validHandle ? KizukiTheme.babyBlueIcons : KizukiTheme.orange)
            PersonAvatar(draft.person.id, size: 96)
                .frame(maxWidth: .infinity).padding(.top, 16)
        case .goal:
            VStack(spacing: 24) {
                ForEach(Goal.allCases, id: \.self) { goal in
                    onboardingChoice(goal.rawValue, selected: draft.goal == goal, height: 111,
                                     illustration: goal == .collaborate ? .onboardingEyes : .onboardingEye) {
                        draft.goal = goal
                        if goal == .explore { draft.person.roles = [] }
                        else if draft.person.roles.isEmpty { draft.person.roles = [draft.person.realm.roleOptions[0]] }
                    }
                }
            }.padding(.top, 28)
            if draft.goal == .collaborate {
                Text("What’s your next move?").font(KizukiTheme.title(24))
                ForEach(Intent.allCases, id: \.self) { intent in
                    onboardingChoice(intent.rawValue, selected: draft.intent == intent, height: 56) { draft.intent = intent }
                }
            }
        case .realm:
            lead(draft.goal == .explore ? "Choose a starting point for discovery. You can browse every realm. No role or availability needed." : "Pick the place you start. You can cross disciplines later.")
            ForEach(Realm.allCases, id: \.self) { realm in
                onboardingChoice(realm.rawValue, selected: draft.person.realm == realm, height: 48) {
                    draft.person.realm = realm; draft.person.roles = draft.goal == .explore ? [] : [realm.roleOptions[0]]
                }
            }
        case .roles:
            lead("Choose one main role and up to three secondary roles. All help matching; your main role weighs more.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 15) {
                ForEach(draft.person.realm.roleOptions, id: \.self) { role in
                    VStack {
                        onboardingChoice(role, selected: draft.person.roles.contains(role), height: 80, tile: true) { toggleRole(role) }
                            .accessibilityValue(draft.person.roles.first == role ? "Main" : draft.person.roles.contains(role) ? "Secondary" : "Not selected")
                        if draft.person.roles.contains(role) {
                            Text(draft.person.roles.first == role ? "Main" : "Secondary").font(KizukiTheme.mono(11))
                            if draft.person.roles.first != role {
                                Button("Make main") { draft.person.roles = RoleSelection.promoting(role, in: draft.person.roles) }
                                    .accessibilityLabel("Make \(role) main").frame(minHeight: 44)
                            }
                        }
                    }
                }
            }
        case .taste:
            lead("A few instincts. Tap the worlds you’d like to explore. These are sample references.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<6, id: \.self) { i in
                    let on = draft.tasteCards.contains(i)
                    Button { if on { draft.tasteCards.remove(i) } else { draft.tasteCards.insert(i) } } label: {
                        VStack(spacing: 0) {
                            Artwork(seed: i, height: 120)
                            HStack {
                                Text(["Quiet stories", "Raw energy", "Analogue warmth", "Dream worlds", "Bold colour", "Small details"][i]).font(KizukiTheme.mono(11))
                                Spacer()
                                if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(KizukiTheme.orange) }
                            }
                            .padding(8).background(KizukiTheme.grey)
                        }
                        .overlay(Rectangle().stroke(on ? KizukiTheme.orange : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Toggle("Use taste to shape recommendations", isOn: $draft.useTasteForMatching).font(KizukiTheme.body(14)).tint(KizukiTheme.orange)
        case .favourites:
            KizukiSearchField("Search films and music", text: $search)
            Text("Films").font(KizukiTheme.title(24)); favouriteRows(Self.films)
            Text("Music").font(KizukiTheme.title(24)); favouriteRows(Self.music)
            Toggle("Show on my profile", isOn: $draft.showFavourites).font(KizukiTheme.body(14)).tint(KizukiTheme.orange)
            Toggle("Use for recommendations", isOn: $draft.useFavouritesForMatching).font(KizukiTheme.body(14)).tint(KizukiTheme.orange)
        case .compensation:
            lead("A label that helps you find the right projects. No payments happen in Kizuki.")
            ForEach(Compensation.allCases, id: \.self) { c in ChoiceRow(c.rawValue, selected: draft.compensation == c) { draft.compensation = c } }
        case .availability:
            lead(OnboardingCopy.availability)
            ForEach(Availability.allCases, id: \.self) { a in ChoiceRow(a.rawValue, selected: draft.availability == a) { draft.availability = a } }
        case .city:
            KizukiField("City (shown on your profile)", text: bind(\.person.city))
            if draft.goal == .collaborate {
                Text("How do you want to work?").font(KizukiTheme.title(24))
                ForEach(WorkMode.allCases, id: \.self) { m in ChoiceRow(m.rawValue, selected: draft.workMode == m) { draft.workMode = m } }
            }
        case .notifications:
            Text(draft.goal == .explore ? "Explore at your own pace. Notification preferences are available in Settings; nothing is enabled here." : "Know when someone wants to create with you, accepts your request, or sends a message.").font(KizukiTheme.poppins(15)).foregroundStyle(KizukiTheme.babyBlueIcons)
        case .location:
            Text("Use your location once to suggest a city. Your exact location is never stored.").font(KizukiTheme.poppins(15)).foregroundStyle(KizukiTheme.babyBlueIcons)

        }
    }

    private var sukiTip: some View {
        HStack(spacing: 24) {
            Text("The more we know about you, the better your recommendations will be.")
                .font(KizukiTheme.title(16)).foregroundStyle(KizukiTheme.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            KizukiIllustration.onboardingSuki.image.resizable().scaledToFit()
                .frame(width: 30, height: 37).accessibilityHidden(true)
        }
        .padding(.horizontal, 15).padding(.vertical, 9).frame(minHeight: 56)
        .background(KizukiTheme.darkGrey)
        .overlay { roughEdge(.onboardingTipEdge) }
        .accessibilityElement(children: .combine)
    }

    private func onboardingPattern(tint: Color) -> some View {
        GeometryReader { geometry in
            let scale = max(geometry.size.width / 393, geometry.size.height / 852)
            KizukiIllustration.onboardingPattern.image.resizable()
                .frame(width: 3862.13 * scale, height: 2143.66 * scale)
                .offset(x: -1160.516 * scale, y: -373.184 * scale)
                .foregroundStyle(tint)
        }
        .clipped().allowsHitTesting(false).accessibilityHidden(true)
    }

    private func roughEdge(_ asset: KizukiIllustration, tint: Color? = nil) -> some View {
        (tint ?? KizukiTheme.cream.opacity(0.6))
            .mask {
                asset.originalImage.resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .contrast(3).luminanceToAlpha()
                    .mask { Rectangle().strokeBorder(lineWidth: 11) }
                    .padding(-3)
            }
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func onboardingChoice(_ title: String, selected: Bool, height: CGFloat,
                                  illustration: KizukiIllustration? = nil, tile: Bool = false,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text(title).font(KizukiTheme.monoMedium(16)).tracking(-0.48)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let illustration {
                    illustration.image.resizable().scaledToFit()
                        .frame(width: illustration == .onboardingEyes ? 74 : 62, height: 64)
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: height, alignment: tile ? .bottomLeading : .center)
            .foregroundStyle(selected ? KizukiTheme.charcoal : KizukiTheme.cream)
            .background(selected ? KizukiTheme.babyBlueIcons : KizukiTheme.darkGrey)
            .overlay { roughEdge(.onboardingCardEdge, tint: tile ? (selected ? KizukiTheme.babyBlueIcons : KizukiTheme.charcoal) : nil) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func lead(_ text: String) -> some View { Text(text).font(KizukiTheme.poppins(14)).foregroundStyle(KizukiTheme.babyBlueIcons) }
    private func bind(_ keyPath: WritableKeyPath<OwnProfile, String>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] }, set: { draft[keyPath: keyPath] = $0 })
    }
    private func toggleRole(_ role: String) {
        draft.person.roles = RoleSelection.toggling(role, in: draft.person.roles, realm: draft.person.realm)
    }

    static let films = ["Perfect Days", "Aftersun", "Paris, Texas", "Moonlight", "Portrait of a Lady on Fire", "Wings of Desire"]
    static let music = ["Nala Sinephro", "Tirzah", "Khruangbin", "Bicep", "Moderat", "Anika"]

    private func favouriteRows(_ names: [String]) -> some View {
        ForEach(names.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { name in
            let on = draft.favourites.contains(name)
            Button { if on { draft.favourites.remove(name) } else { draft.favourites.insert(name) } } label: {
                HStack { Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(KizukiTheme.orange); Text(name); Spacer() }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
        }
    }
}

/// Avatars on the closing screen only need stable ids; they carry no data.
enum FixtureIDs {
    static func sample(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0001-0000-%012d", n))! }
}
#endif
