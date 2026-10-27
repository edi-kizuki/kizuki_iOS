import Foundation

// Domain models for the hero-screen prototype. Live repositories (Supabase) will return the same types.

public enum Realm: String, CaseIterable, Sendable, Hashable, Codable {
    case film = "Film", music = "Music", visualArts = "Visual arts"

    public var roleOptions: [String] {
        switch self {
        case .film: ["Director", "Cinematographer", "Editor", "Producer", "Writer", "Sound designer", "Documentary maker", "Colourist", "Production designer", "Camera operator", "Costume designer", "VFX artist"]
        case .music: ["Musician", "Composer", "Producer", "Singer", "Sound designer", "Mix engineer", "Songwriter", "DJ", "Guitarist", "Bassist", "Drummer", "Keys", "Cellist"]
        case .visualArts: ["Painter", "Illustrator", "Photographer", "Animator", "Art director", "Printmaker", "Sculptor", "Graphic designer", "Motion designer", "Ceramicist", "Textile artist", "Collage artist", "Digital artist"]
        }
    }
}

public enum LinkKind: String, CaseIterable, Sendable, Hashable, Codable {
    case youtube = "YouTube", soundcloud = "SoundCloud", bandcamp = "Bandcamp"
    case instagram = "Instagram", letterboxd = "Letterboxd", tiktok = "TikTok"
    /// v0 rule (decision 23 and the defaults list): three embeds, two link-outs.
    public var isEmbed: Bool { self == .youtube || self == .soundcloud || self == .bandcamp }
    public var iconAsset: String { "Provider" + rawValue }
    public var exampleURL: String {
        switch self {
        case .youtube: "youtube.com/@yourchannel"
        case .soundcloud: "soundcloud.com/yourname"
        case .bandcamp: "yourname.bandcamp.com"
        case .instagram: "instagram.com/yourname"
        case .letterboxd: "letterboxd.com/yourname"
        case .tiktok: "tiktok.com/@yourname"
        }
    }

    public func normalizedPortfolioURL(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }), !trimmed.contains("\\") else { return nil }
        let hasScheme = trimmed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil
        let candidate = hasScheme ? trimmed : "https://" + trimmed
        guard var components = URLComponents(string: candidate), components.scheme?.lowercased() == "https" else { return nil }
        components.scheme = "https"
        components.host = components.host?.lowercased()
        guard let url = components.url?.absoluteString,
              PortfolioWidgetDescriptor(link: ProfileLink(kind: self, title: rawValue, url: url)).state != .invalid else { return nil }
        return url
    }
    public var symbol: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .soundcloud: "waveform"
        case .bandcamp: "opticaldisc"
        case .instagram: "camera"
        case .letterboxd: "film"
        case .tiktok: "music.note"
        }
    }
}

public struct ProfileLink: Sendable, Hashable, Identifiable, Codable {
    public var id: String { kind.rawValue }
    public let kind: LinkKind
    public let title: String
    public let url: String
    private let enabled: Bool?
    public var isEnabled: Bool { enabled != false }
    public init(kind: LinkKind, title: String, url: String, isEnabled: Bool = true) {
        self.kind = kind; self.title = title; self.url = url; self.enabled = isEnabled ? nil : false
    }
}

public struct PortfolioWidgetDescriptor: Sendable, Equatable {
    public enum State: Sendable { case invalid, linkOnly, embedAvailable, metadataRequired }
    public let state: State
    public let externalURL: URL?
    public let embedURL: URL?
    public var requiresPlaybackConsent: Bool { embedURL != nil || state == .metadataRequired }

    public init(link: ProfileLink) {
        guard var components = URLComponents(string: link.url), components.scheme == "https",
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased(), let original = components.url else {
            state = .invalid; externalURL = nil; embedURL = nil; return
        }
        let allowed: Bool
        switch link.kind {
        case .youtube: allowed = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"].contains(host)
        case .soundcloud: allowed = ["soundcloud.com", "www.soundcloud.com"].contains(host)
        case .bandcamp: allowed = host == "bandcamp.com" || host.hasSuffix(".bandcamp.com")
        case .instagram: allowed = ["instagram.com", "www.instagram.com"].contains(host)
        case .letterboxd: allowed = ["letterboxd.com", "www.letterboxd.com"].contains(host)
        case .tiktok: allowed = ["tiktok.com", "www.tiktok.com", "m.tiktok.com", "vm.tiktok.com", "vt.tiktok.com"].contains(host)
        }
        guard allowed else { state = .invalid; externalURL = nil; embedURL = nil; return }
        components.fragment = nil
        let parts = components.path.split(separator: "/").map(String.init)
        var player: URL?
        var resolvedState: State = .linkOnly
        if link.kind == .youtube {
            let videoID: String?
            if host == "youtu.be", parts.count == 1 { videoID = parts.first }
            else if components.path == "/watch" { videoID = components.queryItems?.first(where: { $0.name == "v" })?.value }
            else if parts.count == 2, ["shorts", "embed"].contains(parts[0]) { videoID = parts[1] }
            else { videoID = nil }
            if let videoID, videoID.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil {
                player = URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=0&playsinline=1")
                resolvedState = .embedAvailable
            }
        } else if link.kind == .soundcloud, parts.count == 2 || (parts.count == 3 && parts[1] == "sets") {
            components.query = nil
            var widget = URLComponents(string: "https://w.soundcloud.com/player/")!
            widget.queryItems = [URLQueryItem(name: "url", value: components.url?.absoluteString), URLQueryItem(name: "auto_play", value: "false")]
            player = widget.url
            resolvedState = .embedAvailable
        } else if link.kind == .bandcamp, parts.count == 2, ["album", "track"].contains(parts[0]) {
            resolvedState = .metadataRequired
        }
        state = resolvedState
        externalURL = original
        embedURL = player
    }
}

public struct Person: Identifiable, Sendable, Hashable, Codable {
    public var portraitAsset: String?
    public var collaborationEnabled: Bool?
    public let id: UUID
    public var name: String
    public var handle: String
    public var realm: Realm
    public var roles: [String]
    public var city: String
    public var bio: String
    public var links: [ProfileLink]
    public var visibleLinks: [ProfileLink] { links.filter(\.isEnabled) }
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
    public var acceptsCollaboration: Bool { collaborationEnabled != false }
}

public enum Goal: String, CaseIterable, Sendable, Codable { case collaborate = "I want to collaborate", explore = "Explore and get inspired" }
public enum Intent: String, CaseIterable, Sendable, Codable { case start = "Start a project", join = "Join a project" }
public enum Compensation: String, CaseIterable, Sendable, Hashable, Codable {
    case paid = "Paid work", passion = "Passion projects", open = "Open to either"
}
public enum WorkMode: String, CaseIterable, Sendable, Hashable, Codable { case local = "Local", remote = "Remote", both = "Both" }
public enum Availability: String, CaseIterable, Sendable, Hashable, Codable {
    case low = "Under 5 hours / week", mid = "5–10 hours / week", high = "10+ hours / week"
}

/// The signed-in creator: public profile fields plus private onboarding answers.
public struct OwnProfile: Sendable, Equatable, Codable {
    public var onboardingCompleted: Bool?
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

public enum RoleSelection {
    public static func isValid(_ roles: [String], realm: Realm, allowEmpty: Bool = false) -> Bool {
        (allowEmpty || !roles.isEmpty) && roles.count <= 4 && Set(roles).count == roles.count && roles.allSatisfy(realm.roleOptions.contains)
    }

    public static func toggling(_ role: String, in roles: [String], realm: Realm) -> [String] {
        guard realm.roleOptions.contains(role) else { return roles }
        if roles.contains(role) { return roles.count > 1 ? roles.filter { $0 != role } : roles }
        return roles.count < 4 ? roles + [role] : roles
    }

    public static func promoting(_ role: String, in roles: [String]) -> [String] {
        guard roles.contains(role) else { return roles }
        return [role] + roles.filter { $0 != role }
    }

    public static func score(_ roles: [String], matching candidates: [String]) -> Int {
        roles.enumerated().reduce(0) { $0 + (candidates.contains($1.element) ? ($1.offset == 0 ? 4 : 1) : 0) }
    }
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
