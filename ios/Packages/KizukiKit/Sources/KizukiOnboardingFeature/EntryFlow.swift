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
    case handle, goal, realm, roles, taste, favourites, compensation, availability, city, notifications, location, ready
    public var id: String {
        ["handle", "goal", "realm", "roles", "taste", "favourites", "compensation", "availability", "city", "primer-notifications", "primer-location", "ready"][rawValue]
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
    @State private var screen: EntryScreen
    @State private var draft: OwnProfile
    @State private var emailEntry = false
    @State private var email = "mika@example.com"
    @State private var password = "prototype"
    @State private var ageAndTerms = false
    @State private var showTerms = false
    @State private var search = ""
    let onFinish: (OwnProfile) -> Void
    let autoAdvanceSplash: Bool

    public init(start: EntryScreen = .splash, autoAdvanceSplash: Bool = true, initial: OwnProfile, onFinish: @escaping (OwnProfile) -> Void) {
        _screen = State(initialValue: start)
        _draft = State(initialValue: initial)
        self.onFinish = onFinish
        self.autoAdvanceSplash = autoAdvanceSplash
    }

    private let titles = ["What should we call you?", "What are you looking to do?", "Find your creative realm", "What’s your role?",
                          "What catches your eye?", "Your favourites, your world", "What kind of work?", "How much time do you have?",
                          "Where do you create?", "Stay in the loop", "Find your nearby people", "You’re in good company"]

    public var body: some View {
        Group {
            switch screen {
            case .splash: splash
            case .login: login
            case .eligibility: eligibility
            case let .step(step): stepScreen(step)
            }
        }
        .background(screen == .splash ? KizukiTheme.orange : screen == .login ? KizukiTheme.ink : KizukiTheme.charcoal)
        .foregroundStyle(KizukiTheme.cream)
        .task(id: screen) {
            if screen == .splash, autoAdvanceSplash { try? await Task.sleep(for: .seconds(1.6)); if screen == .splash { screen = .login } }
        }
        .sheet(isPresented: $showTerms) { termsSheet }
    }

    // MARK: Entry

    private var splash: some View {
        VStack(spacing: 12) {
            Spacer()
            KizukiIcon.wordmark.image.resizable().scaledToFit().frame(width: 280).foregroundStyle(KizukiTheme.charcoal)
                .accessibilityLabel("Kizuki")
            Text("FIND YOUR PEOPLE.").font(KizukiTheme.mono(14)).tracking(3).foregroundStyle(KizukiTheme.charcoal)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var login: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            KizukiIcon.kMark.image.resizable().scaledToFit().frame(height: 84).foregroundStyle(KizukiTheme.orange).accessibilityHidden(true)
            Text("LET’S GET\nCREATIVE.").font(KizukiTheme.title(64)).lineSpacing(-6)
            Text("Find your people.\nMake something real.").font(KizukiTheme.body(20)).foregroundStyle(KizukiTheme.babyBlue)
            Spacer()
            if emailEntry {
                KizukiField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    SecureField("Password", text: $password).padding(.vertical, 10)
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
        .padding(32)
    }

    private var eligibility: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("GOOD PEOPLE.\nGOOD GROUND RULES.").font(KizukiTheme.title(40))
            Text("A creative community for adults. Let’s keep it thoughtful, safe and kind.").font(KizukiTheme.body(18)).foregroundStyle(KizukiTheme.babyBlueIcons)
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
        VStack(spacing: 0) {
            if !step.isPrimer {
                HStack(spacing: 5) {
                    ForEach(0..<12) { n in Capsule().fill(n <= step.rawValue ? KizukiTheme.orange : KizukiTheme.grey).frame(height: 4) }
                }
                .padding(.horizontal, 20).padding(.top, 14).accessibilityHidden(true)
                HStack {
                    Button { go(back: step) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous step")
                    Spacer()
                    Text("\(step.rawValue + 1) / 12").font(KizukiTheme.mono()).foregroundStyle(KizukiTheme.babyBlueIcons)
                }
                .padding(.horizontal, 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if step.isPrimer {
                        Image(systemName: step == .notifications ? "bell.badge" : "location.circle")
                            .font(.system(size: 80, weight: .ultraLight)).foregroundStyle(KizukiTheme.blue)
                            .frame(maxWidth: .infinity).padding(.top, 60).accessibilityHidden(true)
                    }
                    Text(titles[step.rawValue].uppercased()).font(KizukiTheme.title(36)).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, step.isPrimer ? 20 : 10).accessibilityAddTraits(.isHeader)
                    content(step)
                }
                .padding(.horizontal, 28).padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            // Primers carry exactly one button (decision 31).
            PrimaryButton(step == .ready ? "Enter Kizuki" : "Continue") { go(next: step) }
                .disabled(step == .handle && !validHandle)
                .padding(.horizontal, 56).padding(.bottom, 24).padding(.top, 8)
        }
    }

    private func go(next step: OnboardingStep) {
        if step == .ready { onFinish(draft) } else if let n = OnboardingStep(rawValue: step.rawValue + 1) { screen = .step(n) }
    }
    private func go(back step: OnboardingStep) {
        if let p = OnboardingStep(rawValue: step.rawValue - 1) { screen = .step(p) } else { screen = .eligibility }
    }

    @ViewBuilder private func content(_ step: OnboardingStep) -> some View {
        switch step {
        case .handle:
            lead("A name for the credits. A handle for your people.")
            KizukiField("Display name", text: bind(\.person.name))
            KizukiField("Handle", text: bind(\.person.handle)).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text("3–20 lowercase letters, numbers, dots or underscores.").font(KizukiTheme.mono(11))
                .foregroundStyle(validHandle ? KizukiTheme.babyBlueIcons : KizukiTheme.orange)
            PersonAvatar(draft.person.id, size: 96).frame(maxWidth: .infinity).padding(.top, 16)
        case .goal:
            ForEach(Goal.allCases, id: \.self) { goal in ChoiceRow(goal.rawValue, selected: draft.goal == goal) { draft.goal = goal } }
            if draft.goal == .collaborate {
                Text("What’s your next move?").font(KizukiTheme.title(24))
                ForEach(Intent.allCases, id: \.self) { intent in ChoiceRow(intent.rawValue, selected: draft.intent == intent) { draft.intent = intent } }
            }
        case .realm:
            lead("Pick the place you start. You can cross disciplines later.")
            ForEach(Realm.allCases, id: \.self) { realm in
                ChoiceRow(realm.rawValue, selected: draft.person.realm == realm) {
                    draft.person.realm = realm; draft.person.roles = [realm.roleOptions[0]]
                }
            }
        case .roles:
            lead("Choose up to three. Your first role is your starting point.")
            FlowLayout(spacing: 10) {
                ForEach(draft.person.realm.roleOptions, id: \.self) { role in
                    Button { toggleRole(role) } label: { KizukiChip(role, selected: draft.person.roles.contains(role)).frame(minHeight: 44) }
                        .buttonStyle(.plain).accessibilityAddTraits(draft.person.roles.contains(role) ? .isSelected : [])
                }
            }
        case .taste:
            lead("A few instincts. Tap the worlds you’d like to explore. Placeholder images.")
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
            Text("How do you want to work?").font(KizukiTheme.title(24))
            ForEach(WorkMode.allCases, id: \.self) { m in ChoiceRow(m.rawValue, selected: draft.workMode == m) { draft.workMode = m } }
        case .notifications:
            Text("Know when someone wants to create with you, accepts your request, or sends a message.").font(KizukiTheme.body(18)).foregroundStyle(KizukiTheme.babyBlueIcons)
        case .location:
            Text("Use your location once to suggest a city. Your exact location is never stored.").font(KizukiTheme.body(18)).foregroundStyle(KizukiTheme.babyBlueIcons)
        case .ready:
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { n in PersonAvatar(FixtureIDs.sample(n), size: 72) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
            Text("Your creative space is ready, \(draft.person.firstName).").font(KizukiTheme.body(20))
            Text("Film, music, visual arts. A city full of possibilities.").foregroundStyle(KizukiTheme.babyBlueIcons)
        }
    }

    private func lead(_ text: String) -> some View { Text(text).font(KizukiTheme.body(16)).foregroundStyle(KizukiTheme.babyBlueIcons) }
    private func bind(_ keyPath: WritableKeyPath<OwnProfile, String>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] }, set: { draft[keyPath: keyPath] = $0 })
    }
    private func toggleRole(_ role: String) {
        if draft.person.roles.contains(role) { if draft.person.roles.count > 1 { draft.person.roles.removeAll { $0 == role } } }
        else if draft.person.roles.count < 3 { draft.person.roles.append(role) }
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
