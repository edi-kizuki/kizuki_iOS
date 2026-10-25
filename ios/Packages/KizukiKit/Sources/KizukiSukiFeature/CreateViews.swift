import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct CreateProjectView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var title = ""
    @State private var summary = ""
    @State private var realm: Realm = .film
    @State private var roles: Set<String> = []
    @State private var compensation: Compensation = .passion
    @State private var workMode: WorkMode = .local
    @State private var time: Availability = .mid
    @State private var seats = 2
    @State private var city = "Berlin, DE"
    public init() {}

    private var valid: Bool { title.trimmingCharacters(in: .whitespaces).count >= 3 }

    public var body: some View {
        PageScroll(spacing: 18) {
            Artwork(seed: title.count, height: 120).clipShape(RoundedRectangle(cornerRadius: 4))
            KizukiField("Name", text: $title, prompt: "Name your project")
            KizukiTextArea("Description", text: $summary)
            label("Category")
            FlowLayout(spacing: 8) { ForEach(Realm.allCases, id: \.self) { r in
                Button { realm = r; roles = [] } label: { KizukiChip(r.rawValue, selected: realm == r).frame(minHeight: 44) }.buttonStyle(.plain)
            } }
            label("Roles needed")
            FlowLayout(spacing: 8) {
                ForEach(realm.roleOptions, id: \.self) { role in
                    Button { if roles.contains(role) { roles.remove(role) } else { roles.insert(role) } } label: { KizukiChip(role, selected: roles.contains(role)).frame(minHeight: 44) }.buttonStyle(.plain)
                }
            }
            label("Compensation (a label only)")
            FlowLayout(spacing: 8) { ForEach([Compensation.paid, .passion, .open], id: \.self) { c in
                Button { compensation = c } label: { KizukiChip(c.rawValue, selected: compensation == c).frame(minHeight: 44) }.buttonStyle(.plain)
            } }
            label("Set up")
            FlowLayout(spacing: 8) { ForEach(WorkMode.allCases, id: \.self) { m in
                Button { workMode = m } label: { KizukiChip(m.rawValue, selected: workMode == m).frame(minHeight: 44) }.buttonStyle(.plain)
            } }
            KizukiField("City", text: $city)
            label("Time investment")
            ForEach(Availability.allCases, id: \.self) { a in ChoiceRow(a.rawValue, selected: time == a) { time = a } }
            Stepper("Open seats: \(seats)", value: $seats, in: 1...8).font(KizukiTheme.body(15))
            PrimaryButton("Publish project", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) { save(.published) }.disabled(!valid)
            OutlineButton("Save as draft") { save(.draft) }.disabled(!valid)
        }
        .navigationTitle("Create a project").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { router.sheet = nil } } }
    }

    private func label(_ text: String) -> some View { Text(text).font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons) }

    private func save(_ status: ProjectStatus) {
        let project = Project(id: UUID(), ownerID: store.me.id, title: title, realm: realm,
                              rolesNeeded: roles.isEmpty ? [realm.roleOptions[0]] : Array(roles).sorted(), summary: summary.isEmpty ? "A new idea, still taking shape." : summary,
                              status: status, compensation: compensation, city: city, workMode: workMode, timeCommitment: time, seats: seats, artSeed: title.count)
        Task {
            await store.saveProject(project)
            router.sheet = nil
            router.tab = .myProjects
        }
    }
}

public struct PostCollabView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var caption = ""
    @State private var tags = ""
    public init() {}

    public var body: some View {
        PageScroll(spacing: 18) {
            Artwork(seed: caption.count + 2, height: 260, title: "Photo placeholder").clipShape(RoundedRectangle(cornerRadius: 4))
            Text("The real app opens the photo picker here.").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            KizukiField("Caption", text: $caption, prompt: "What are you making?")
            KizukiField("Tags (comma separated)", text: $tags, prompt: "film, light")
            PrimaryButton("Post", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) {
                let list = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                Task { await store.postCollab(caption: caption, tags: list); router.sheet = nil; router.tab = .profile }
            }
            .disabled(caption.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationTitle("Post a collab").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { router.sheet = nil } } }
    }
}
