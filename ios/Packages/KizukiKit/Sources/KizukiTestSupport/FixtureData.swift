#if DEBUG
import Foundation
import KizukiCore

/// One shared set of invented data: 20 Berlin-first creators, 10 projects, requests in every state, 3 chats.
/// Every name, handle and link is fictional. Compiled in Debug only (concept v2 2.2, C-34).
public enum FixtureData {
    public static func id(_ kind: Int, _ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-%04d-0000-%012d", kind, n))!
    }
    public static func personID(_ n: Int) -> UUID { id(1, n) }
    public static func projectID(_ n: Int) -> UUID { id(2, n) }
    public static func requestID(_ n: Int) -> UUID { id(3, n) }
    public static var meID: UUID { personID(0) }

    static let names = ["Mika Voss", "Leni Falk", "Noah Idris", "Aya Morita", "Emil Sander", "Zara Okafor", "Jules Marin", "Ada Nowak",
                        "Sami Keller", "Nia Lorenz", "Theo Silva", "Romy Chen", "Ivo Berg", "Alma Reyes", "Finn Kaya", "Esra Wolf",
                        "Leon Park", "Mara Rossi", "Oli Santos", "Tessa Reed"]
    static let realms: [Realm] = [.film, .film, .music, .visualArts, .music, .visualArts, .film, .visualArts, .music, .film,
                                  .film, .visualArts, .visualArts, .film, .music, .music, .film, .music, .visualArts, .visualArts]
    static let roles: [[String]] = [
        ["Director", "Writer"], ["Cinematographer"], ["Producer", "Keys"], ["Illustrator", "Animator"], ["Sound designer"],
        ["Photographer"], ["Editor"], ["Illustrator"], ["Composer"], ["Documentary maker"], ["Colourist"], ["Printmaker"],
        ["Sculptor"], ["Production designer"], ["Guitarist"], ["Cellist"], ["Editor", "Director"], ["Singer", "Songwriter"],
        ["Art director"], ["Graphic designer"]]
    static let bios = [
        "Making little films about big feelings. Usually carrying a field recorder. Looking for kind people to make strange things with.",
        "Chasing quiet moments and unexpected textures. Let's make something with feeling.",
        "Independent, curious, happiest in a room full of people making things.",
        "A practice somewhere between analogue memories and new possibilities."]
    static let favouriteFilms = ["Perfect Days", "Aftersun", "Paris, Texas", "Moonlight"]
    static let favouriteMusic = ["Nala Sinephro", "Tirzah", "Khruangbin", "Bicep"]

    static func links(_ i: Int) -> [ProfileLink] {
        let h = names[i].lowercased().replacingOccurrences(of: " ", with: ".")
        var out: [ProfileLink] = []
        switch realms[i] {
        case .film:
            out.append(ProfileLink(kind: .youtube, title: "Blue hour (short, 2025)", url: "https://youtube.example/\(h)"))
            out.append(ProfileLink(kind: .letterboxd, title: "Letterboxd", url: "https://letterboxd.example/\(h)"))
        case .music:
            out.append(ProfileLink(kind: .soundcloud, title: "Ringbahn sketches", url: "https://soundcloud.example/\(h)"))
            out.append(ProfileLink(kind: .bandcamp, title: "Small Hours EP", url: "https://\(h).bandcamp.example"))
        case .visualArts:
            out.append(ProfileLink(kind: .youtube, title: "Studio process, week 12", url: "https://youtube.example/\(h)"))
            out.append(ProfileLink(kind: .instagram, title: "Instagram", url: "https://instagram.example/\(h)"))
        }
        if i % 3 == 0 { out.append(ProfileLink(kind: .instagram, title: "Instagram", url: "https://instagram.example/\(h)")) }
        return out
    }

    public static let people: [Person] = names.enumerated().map { i, name in
        // The signed-in user (index 0) starts without a bio, so the "Get discovered" card has something to ask for.
        Person(id: personID(i), name: name, handle: name.lowercased().replacingOccurrences(of: " ", with: "."),
               realm: realms[i], roles: roles[i], city: i == 17 ? "Potsdam, DE" : "Berlin, DE", bio: i == 0 ? "" : bios[i % bios.count],
               links: links(i), favourites: i % 2 == 0 ? [favouriteFilms[i % 4], favouriteMusic[(i + 1) % 4]] : [],
               availability: Availability.allCases[(i + 1) % 3])
    }

    static let projectTitles = ["Blue hour, Berlin", "A room for sound", "Soft edges", "Letters from Wedding", "Night bus diaries",
                                "Paper futures", "The quiet between", "Concrete bloom", "A small orbit", "Sunday, again"]
    static let projectSummaries = [
        "A short film about two strangers who miss the last train. Looking for a small, thoughtful crew for two evenings in Neukölln.",
        "An intimate live session built around field recordings and warm analogue textures. Come shape it with us.",
        "A collaborative study of the city: found paper, changing light and the stories in between."]

    public static let projects: [Project] = {
        // (owner, status, members, realm, rolesNeeded, compensation)
        let spec: [(Int, ProjectStatus, [Int], Realm, [String], Compensation)] = [
            (0, .draft, [], .film, ["Cinematographer", "Sound designer"], .passion),
            (0, .draft, [], .music, ["Composer", "Mix engineer"], .open),
            (0, .published, [3], .visualArts, ["Photographer", "Illustrator"], .passion),
            (1, .published, [0], .film, ["Editor", "Colourist"], .open),
            (2, .published, [], .music, ["Singer", "Guitarist"], .paid),
            (3, .published, [], .visualArts, ["Printmaker", "Art director"], .passion),
            (4, .published, [], .music, ["Cellist", "Sound designer"], .open),
            (5, .published, [], .visualArts, ["Sculptor", "Photographer"], .paid),
            (6, .past, [0], .film, ["Director", "Editor"], .passion),
            (0, .past, [1], .film, ["Producer"], .passion)]
        return spec.enumerated().map { i, s in
            Project(id: projectID(i), ownerID: personID(s.0), title: projectTitles[i], realm: s.3, rolesNeeded: s.4,
                    summary: projectSummaries[i % 3], status: s.1, compensation: s.5,
                    workMode: i % 4 == 3 ? .both : .local, timeCommitment: i % 2 == 0 ? .mid : .low,
                    seats: 2 + i % 3, memberIDs: s.2.map(personID), artSeed: i)
        }
    }()

    public static let requests: [CollabRequest] = [
        // Incoming
        r(0, 4, 2, .incoming, .pending, "Sound designer", "5–10 hours / week", "Your blue-hour idea stayed with me. I’d love to build its sound world from recordings around Hermannplatz."),
        r(1, 5, 2, .incoming, .pending, "Photographer", "Under 5 hours / week", "Could help with stills and a little behind-the-scenes story."),
        r(2, 3, 2, .incoming, .accepted, "Illustrator", "5–10 hours / week", "Let’s make it happen."),
        r(3, 10, 2, .incoming, .declined, "Colourist", "Under 5 hours / week", "Happy to grade whatever you shoot."),
        r(4, 11, 2, .incoming, .withdrawn, "Printmaker", "10+ hours / week", "Timing changed on my side."),
        r(5, 9, 2, .incoming, .expired, "Documentary maker", "Under 5 hours / week", "Could we make a moving poster?"),
        // Outgoing
        r(6, 3, 5, .outgoing, .pending, "Art director", "5–10 hours / week", "I’d love to help find the rhythm of this story."),
        r(7, 2, 4, .outgoing, .accepted, "Producer", "5–10 hours / week", "Let’s try a session."),
        r(8, 1, 3, .outgoing, .accepted, "Director", "5–10 hours / week", "Happy to join as a second pair of eyes."),
        r(9, 4, 6, .outgoing, .declined, "Composer", "Under 5 hours / week", "A small musical experiment?"),
        r(10, 5, 7, .outgoing, .withdrawn, "Writer", "10+ hours / week", "Timing changed on my side."),
        r(11, 6, 8, .outgoing, .expired, "Editor", "5–10 hours / week", "Would love to cut this one."),
        // Wish to Collab: requests made from a profile, with no project (decision 52).
        r(12, 7, nil, .incoming, .pending, "Illustrator", "Under 5 hours / week", "No project yet. I love your colour work and would like to make something small together."),
        r(13, 12, nil, .outgoing, .pending, "Director", "5–10 hours / week", "Your sculpture work stayed with me. Could we make something small together?")]

    private static func r(_ n: Int, _ person: Int, _ project: Int?, _ d: RequestDirection, _ s: RequestState, _ role: String, _ time: String, _ note: String) -> CollabRequest {
        CollabRequest(id: requestID(n), personID: personID(person), projectID: project.map(projectID), direction: d, state: s, role: role, timeCommitment: time, note: note)
    }

    public static let conversations: [Conversation] = [1, 2, 3].map { p in
        let last: String
        switch p {
        case 1: last = "Shall we scout along the canal on Sunday? The light around 5 is beautiful."
        case 2: last = "I have a few ideas for our first session. How is Sunday afternoon?"
        default: last = "Sent you two reference stills. Tell me what you think."
        }
        return Conversation(personID: personID(p), projectTitle: p == 3 ? projectTitles[2] : p == 1 ? projectTitles[3] : projectTitles[4], messages: [
            ChatMessage(text: "Hey Mika! So happy we’re making this together.", fromMe: false),
            ChatMessage(text: "Same here. I loved the references you shared.", fromMe: true),
            ChatMessage(text: last, fromMe: false)])
    }

    static let captions = ["Sunday light in the studio", "A little experiment in motion", "Sounds from the Ringbahn", "Blue hour, no script",
                           "Making room for the unexpected", "Cut, paste, repeat"]
    static let tagSets = [["film", "light"], ["motion design"], ["field recording"], ["colour"], ["painting"], ["collage"]]
    /// Every third post is a short video, drawn as a placeholder with a play badge and a duration. No real clips ship.
    static let videoSeconds = [12, 27, 8, 45, 19, 33, 6, 58, 14, 22]
    public static let photos: [CollabPhoto] = (0..<30).map { i in
        CollabPhoto(id: id(4, i), authorID: i % 7 == 0 ? personID(0) : personID(1 + i % 19), caption: captions[i % captions.count],
                    tags: tagSets[i % tagSets.count], artSeed: i, videoSeconds: i % 3 == 1 ? videoSeconds[(i / 3) % videoSeconds.count] : nil)
    }

    public static let ownProfile: OwnProfile = {
        var own = OwnProfile(person: people[0])
        own.favourites = ["Perfect Days", "Nala Sinephro"]
        return own
    }()
}
#endif
