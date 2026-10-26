import Foundation

// Domain models for the hero-screen prototype. Live repositories (Supabase) will return the same types.

public enum Realm: String, CaseIterable, Sendable, Hashable, Codable {
    case film = "Film", music = "Music", visualArts = "Visual arts"

    public var roleOptions: [String] {
        switch self {
        case .film: ["Director", "Cinematographer", "Editor", "Producer", "Writer", "Sound designer"]
        case .music: ["Musician", "Composer", "Producer", "Singer", "Sound designer", "Mix engineer"]
        case .visualArts: ["Illustrator", "Photographer", "Animator", "Art director", "Printmaker", "Sculptor"]
        }
    }
}

public enum LinkKind: String, CaseIterable, Sendable, Hashable {
    case youtube = "YouTube", soundcloud = "SoundCloud", bandcamp = "Bandcamp"
    case instagram = "Instagram", letterboxd = "Letterboxd"
    /// v0 rule (decision 23 and the defaults list): three embeds, two link-outs.
    public var isEmbed: Bool { self == .youtube || self == .soundcloud || self == .bandcamp }
    public var symbol: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .soundcloud: "waveform"
        case .bandcamp: "opticaldisc"
        case .instagram: "camera"
        case .letterboxd: "film"
        }
    }
}

public struct ProfileLink: Sendable, Hashable, Identifiable {
    public var id: String { kind.rawValue }
    public let kind: LinkKind
    public let title: String
    public let url: String
    public init(kind: LinkKind, title: String, url: String) { self.kind = kind; self.title = title; self.url = url }
}

public struct Person: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var handle: String
    public var realm: Realm
    public var roles: [String]
    public var city: String
    public var bio: String
    public var links: [ProfileLink]
    public var favourites: [String]
    /// Public on every profile (decision 51). Work mode and pay preference stay owner-only.
    public var availability: Availability
    public init(id: UUID, name: String, handle: String, realm: Realm, roles: [String], city: String, bio: String,
                links: [ProfileLink] = [], favourites: [String] = [], availability: Availability = .mid) {
        self.id = id; self.name = name; self.handle = handle; self.realm = realm; self.roles = roles
        self.city = city; self.bio = bio; self.links = links; self.favourites = favourites; self.availability = availability
    }
    public var primaryRole: String { roles.first ?? realm.rawValue }
    public var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

public enum Goal: String, CaseIterable, Sendable { case collaborate = "I want to collaborate", explore = "Explore and get inspired" }
public enum Intent: String, CaseIterable, Sendable { case start = "Start a project", join = "Join a project" }
public enum Compensation: String, CaseIterable, Sendable, Hashable {
    case paid = "Paid work", passion = "Passion projects", open = "Open to either"
}
public enum WorkMode: String, CaseIterable, Sendable, Hashable { case local = "Local", remote = "Remote", both = "Both" }
public enum Availability: String, CaseIterable, Sendable, Hashable {
    case low = "Under 5 hours / week", mid = "5–10 hours / week", high = "10+ hours / week"
}

/// The signed-in creator: public profile fields plus private onboarding answers.
public struct OwnProfile: Sendable, Equatable {
    public var person: Person
    public var goal: Goal = .collaborate
    public var intent: Intent = .join
    public var compensation: Compensation = .open
    public var availability: Availability = .mid
    public var workMode: WorkMode = .both
    public var tasteCards: Set<Int> = [0, 2]
    public var favourites: Set<String> = []
    public var showFavourites = true
    public var useFavouritesForMatching = true
    public var useTasteForMatching = true
    public init(person: Person) { self.person = person }
}

public enum ProjectStatus: String, Sendable, Hashable, CaseIterable { case draft = "Draft", published = "Published", closed = "Closed", past = "Past" }

public struct Project: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var ownerID: UUID
    public var title: String
    public var realm: Realm
    public var rolesNeeded: [String]
    public var summary: String
    public var status: ProjectStatus
    public var compensation: Compensation
    public var city: String
    public var workMode: WorkMode
    public var timeCommitment: Availability
    public var seats: Int
    public var memberIDs: [UUID]
    public var artSeed: Int
    public init(id: UUID, ownerID: UUID, title: String, realm: Realm, rolesNeeded: [String], summary: String,
                status: ProjectStatus, compensation: Compensation = .passion, city: String = "Berlin, DE",
                workMode: WorkMode = .local, timeCommitment: Availability = .mid, seats: Int = 2,
                memberIDs: [UUID] = [], artSeed: Int = 0) {
        self.id = id; self.ownerID = ownerID; self.title = title; self.realm = realm; self.rolesNeeded = rolesNeeded
        self.summary = summary; self.status = status; self.compensation = compensation; self.city = city
        self.workMode = workMode; self.timeCommitment = timeCommitment; self.seats = seats
        self.memberIDs = memberIDs; self.artSeed = artSeed
    }
}

public enum RequestState: String, Sendable, Hashable, CaseIterable {
    case pending = "Pending", accepted = "Accepted", declined = "Declined", withdrawn = "Withdrawn", expired = "Expired"
    /// An accepted request whose person was later removed from the Crew (decision 54).
    case ended = "Ended"
}

/// What the request is for (decision 52). A request with no project is a "Wish to Collab" made from a profile.
public enum RequestKind: Sendable, Hashable {
    case wishToCollab, joinProject
    public var label: String { self == .wishToCollab ? "Wish to Collab" : "Join project" }
}
public enum RequestDirection: Sendable, Hashable { case incoming, outgoing }

public struct CollabRequest: Identifiable, Sendable, Hashable {
    public let id: UUID
    /// The other person: the sender of an incoming request, the recipient of an outgoing one.
    public var personID: UUID
    public var projectID: UUID?
    public var direction: RequestDirection
    public var state: RequestState
    public var role: String
    public var timeCommitment: String
    public var note: String
    public init(id: UUID = UUID(), personID: UUID, projectID: UUID?, direction: RequestDirection, state: RequestState,
                role: String, timeCommitment: String, note: String) {
        self.id = id; self.personID = personID; self.projectID = projectID; self.direction = direction
        self.state = state; self.role = role; self.timeCommitment = timeCommitment; self.note = note
    }
    public var kind: RequestKind { projectID == nil ? .wishToCollab : .joinProject }
}

/// No payment fields by design (decision 12).
public struct NewRequest: Sendable {
    public var personID: UUID
    public var projectID: UUID?
    public var role: String
    public var timeCommitment: String
    public var note: String
    public init(personID: UUID, projectID: UUID?, role: String, timeCommitment: String, note: String) {
        self.personID = personID; self.projectID = projectID; self.role = role
        self.timeCommitment = timeCommitment; self.note = note
    }
}

public enum RequestResponse: Sendable { case accept, decline, withdraw }

public struct ChatMessage: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let text: String
    public let fromMe: Bool
    public init(id: UUID = UUID(), text: String, fromMe: Bool) { self.id = id; self.text = text; self.fromMe = fromMe }
}

public struct Conversation: Identifiable, Sendable, Hashable {
    public var id: UUID { personID }
    public let personID: UUID
    public var projectTitle: String?
    public var messages: [ChatMessage]
    public init(personID: UUID, projectTitle: String?, messages: [ChatMessage]) {
        self.personID = personID; self.projectTitle = projectTitle; self.messages = messages
    }
}

public struct CollabPhoto: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let authorID: UUID
    public var caption: String
    public var tags: [String]
    public var artSeed: Int
    /// Length in seconds when this post is a short video. The prototype draws a placeholder, never a real clip (decision 55).
    public var videoSeconds: Int?
    public init(id: UUID = UUID(), authorID: UUID, caption: String, tags: [String], artSeed: Int, videoSeconds: Int? = nil) {
        self.id = id; self.authorID = authorID; self.caption = caption; self.tags = tags; self.artSeed = artSeed; self.videoSeconds = videoSeconds
    }
    public var isVideo: Bool { videoSeconds != nil }
    /// "0:12" style label for the grid badge, or nil for photos.
    public var durationLabel: String? { videoSeconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) } }
}

/// An item with the plain-language reasons it was recommended (rule-based, decision 15).
public struct Recommendation<Item: Sendable & Hashable>: Sendable, Hashable {
    public let item: Item
    public let reasons: [String]
    public init(item: Item, reasons: [String]) { self.item = item; self.reasons = reasons }
}

public enum ReportReason: String, CaseIterable, Sendable { case spam = "Spam", harassment = "Harassment", unsafe = "Unsafe or inappropriate", fake = "Pretending to be someone", other = "Something else" }
