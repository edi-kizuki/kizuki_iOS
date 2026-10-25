import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct SettingsRootView: View {
    @Environment(AppRouter.self) private var router
    public init() {}
    private let symbols: [SettingsPage: String] = [.account: "person.crop.circle", .notifications: "bell", .privacy: "lock.shield", .help: "questionmark.circle", .legal: "doc.text"]

    public var body: some View {
        PageScroll(spacing: 6) {
            ForEach(SettingsPage.allCases, id: \.self) { page in
                Button { router.push(.settingsPage(page)) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: symbols[page] ?? "gearshape").frame(width: 28).foregroundStyle(KizukiTheme.babyBlueIcons)
                        Text(page.rawValue).font(KizukiTheme.bodyBold(15))
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(KizukiTheme.babyBlueIcons)
                    }
                    .frame(minHeight: 53).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(KizukiTheme.grey)
            }
            Text("Kizuki prototype · fixture data only").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons).padding(.top, 12)
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }
}

public struct SettingsPageView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let page: SettingsPage
    @State private var pushRequests = true
    @State private var pushAccepts = true
    @State private var pushMessages = true
    @State private var emailDigest = false
    public init(page: SettingsPage) { self.page = page }

    public var body: some View {
        PageScroll(spacing: 18) {
            switch page {
            case .account: account
            case .notifications: notifications
            case .privacy: privacy
            case .help:
                row("Contact support", "support@kizuki.example")
                row("Community guidelines", "Be kind. Make things. Respect consent.")
                row("Safety tips", "Meet in public places first.")
            case .legal:
                row("Terms of service", "Sample copy for the prototype")
                row("Privacy policy", "Sample copy for the prototype")
                row("Credits", "Londrina Solid, DM Sans, DM Mono (OFL). Blobatar (MIT).")
                row("Version", "Prototype 0.1")
            }
        }
        .navigationTitle(page.rawValue).navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(KizukiTheme.bodyBold(15))
            Text(detail).font(KizukiTheme.body(13)).foregroundStyle(KizukiTheme.babyBlueIcons)
        }
        .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
    }

    @ViewBuilder private var account: some View {
        row("Display name", store.me.name)
        row("Handle", "@\(store.me.handle)")
        row("Email", "mika@example.com")
        row("Sign-in", "Email and password (Apple available)")
        OutlineButton("Edit profile") { router.sheet = .editProfile }
        OutlineButton("Sign out") { }
        Button { router.push(.deleteAccount) } label: {
            Text("Delete account").font(KizukiTheme.mono(14)).frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(KizukiTheme.orange).overlay(Capsule().stroke(KizukiTheme.orange, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var notifications: some View {
        Toggle("New request", isOn: $pushRequests)
        Toggle("Request accepted", isOn: $pushAccepts)
        Toggle("New message", isOn: $pushMessages)
        Toggle("Email digest", isOn: $emailDigest)
        Text("Push notifications are mock toggles in the prototype.").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
    }

    @ViewBuilder private var privacy: some View {
        Text("Matching").font(KizukiTheme.title(22))
        Toggle("Use favourites for recommendations", isOn: Binding(get: { store.own.useFavouritesForMatching }, set: { v in store.updateOwn { $0.useFavouritesForMatching = v } }))
        Toggle("Use taste for recommendations", isOn: Binding(get: { store.own.useTasteForMatching }, set: { v in store.updateOwn { $0.useTasteForMatching = v } }))
        Toggle("Show favourites on my profile", isOn: Binding(get: { store.own.showFavourites }, set: { v in store.updateOwn { $0.showFavourites = v } }))
        Text("Blocked accounts").font(KizukiTheme.title(22)).padding(.top, 8)
        if store.blockedPeople.isEmpty { Text("You haven’t blocked anyone.").font(KizukiTheme.body(13)).foregroundStyle(KizukiTheme.babyBlueIcons) }
        ForEach(store.blockedPeople) { person in
            HStack {
                PersonRow(id: person.id, name: person.name, subtitle: "@\(person.handle)", trailing: "nosign")
                Button("Unblock") { Task { await store.unblock(person.id) } }.buttonStyle(.bordered).tint(KizukiTheme.babyBlue).frame(minHeight: 44)
            }
        }
    }
}

public struct DeleteAccountView: View {
    @State private var confirming = false
    @State private var deleted = false
    public init() {}
    public var body: some View {
        PageScroll(spacing: 18) {
            if deleted {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle").font(.system(size: 64)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    Text("Your account was deleted").font(KizukiTheme.title(30))
                    Text("Prototype only. Nothing was changed.").font(KizukiTheme.mono(12)).foregroundStyle(KizukiTheme.babyBlueIcons)
                }.frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                Text("Delete your account?").font(KizukiTheme.title(32))
                Text("Your profile, projects and requests are removed. Your messages stay visible to the people you sent them to as “Deleted user” for 30 days, then the text is erased.")
                    .font(KizukiTheme.body(15)).foregroundStyle(KizukiTheme.babyBlueIcons)
                Button { confirming = true } label: {
                    Text("Delete account").font(KizukiTheme.titleBlack(18)).frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(KizukiTheme.cream).background(KizukiTheme.orange)
                }.buttonStyle(.plain)
            }
        }
        .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete account permanently?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { deleted = true }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This is a confirmation only in the prototype.") }
    }
}

public struct ReportSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let personID: UUID
    @State private var reason: ReportReason = .spam
    @State private var context = ""
    @State private var done = false
    @State private var alsoBlock = false
    public init(personID: UUID) { self.personID = personID }

    public var body: some View {
        PageScroll(spacing: 16) {
            if done {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.shield").font(.system(size: 60)).foregroundStyle(KizukiTheme.blue)
                    Text("Thanks.").font(KizukiTheme.title(32))
                    Text("We review reports within 24 hours.").font(KizukiTheme.body(15)).foregroundStyle(KizukiTheme.babyBlueIcons)
                    PrimaryButton("Done") { router.sheet = nil }.padding(.horizontal, 40)
                }.frame(maxWidth: .infinity).padding(.top, 30)
            } else {
                Text("Report \(store.person(personID)?.name ?? "this person")").font(KizukiTheme.title(28))
                ForEach(ReportReason.allCases, id: \.self) { r in ChoiceRow(r.rawValue, selected: reason == r) { reason = r } }
                KizukiTextArea("Anything we should know? (optional)", text: $context)
                Toggle("Also block this person", isOn: $alsoBlock).tint(KizukiTheme.orange)
                PrimaryButton("Send report") {
                    Task {
                        await store.report(personID, reason: reason, context: context)
                        if alsoBlock { await store.block(personID) }
                        done = true
                    }
                }
            }
        }
        .navigationTitle("Report").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { router.sheet = nil } } }
    }
}
