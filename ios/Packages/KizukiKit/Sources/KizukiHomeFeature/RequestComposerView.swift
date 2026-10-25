#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

/// Request form: role, time investment, note. No payment block (decision 12).
public struct RequestComposerView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let personID: UUID
    let projectID: UUID?
    @State private var role: String = ""
    @State private var time: Availability = .mid
    @State private var note = ""
    @State private var sent = false

    public init(personID: UUID, projectID: UUID?) { self.personID = personID; self.projectID = projectID }

    private var roleOptions: [String] {
        if let projectID, let project = store.project(projectID) { return project.rolesNeeded }
        return store.me.roles
    }

    public var body: some View {
        let person = store.person(personID)
        PageScroll(spacing: 20) {
            if sent {
                VStack(spacing: 14) {
                    Image(systemName: "paperplane.circle.fill").font(.system(size: 70)).foregroundStyle(KizukiTheme.blue)
                    Text(projectID == nil ? "Wish sent" : "Request sent").font(KizukiTheme.title(32))
                    Text("\(person?.firstName ?? "They") will see it in Suki > Requests. You can chat once it’s accepted.")
                        .font(KizukiTheme.body(15)).foregroundStyle(KizukiTheme.babyBlueIcons).multilineTextAlignment(.center)
                    PrimaryButton("Done") { router.sheet = nil }.padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                if let person {
                    HStack(spacing: 12) {
                        PersonAvatar(person.id, size: 48)
                        VStack(alignment: .leading) {
                            Text(projectID.flatMap { store.project($0)?.title } ?? "Wish to Collab with \(person.firstName)").font(KizukiTheme.title(24))
                            Text(projectID == nil ? "To \(person.name) · no project needed" : "Join project · to \(person.name)").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                        }
                    }
                }
                Text("Role").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                HStack { ForEach(roleOptions, id: \.self) { r in
                    Button { role = r } label: { KizukiChip(r, selected: role == r).frame(minHeight: 44) }.buttonStyle(.plain)
                } }
                Text("Time investment").font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
                ForEach(Availability.allCases, id: \.self) { a in ChoiceRow(a.rawValue, selected: time == a) { time = a } }
                KizukiTextArea("Note", text: $note)
                PrimaryButton("Send request", color: KizukiTheme.yellow, textColor: KizukiTheme.charcoal) {
                    let request = NewRequest(personID: personID, projectID: projectID, role: role.isEmpty ? (roleOptions.first ?? "Collaborator") : role,
                                             timeCommitment: time.rawValue, note: note)
                    Task { await store.sendRequest(request); sent = true }
                }
            }
        }
        .navigationTitle(sent ? "" : (projectID == nil ? "Wish to Collab" : "Join project")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { router.sheet = nil } } }
        .onAppear { if role.isEmpty { role = roleOptions.first ?? "" } }
    }
}
#endif
