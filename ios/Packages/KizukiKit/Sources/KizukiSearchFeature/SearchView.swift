#if DEBUG // Prototype screens (fixture-backed). Not compiled into Staging or Release until a live equivalent replaces them.
import KizukiCore
import KizukiDesignSystem
import SwiftUI

public struct SearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = ""
    @State private var filter = "For you"
    private let filters = ["For you", "Film", "Music", "Visual arts", "Motion design", "Painting"]

    public init() {}

    private var results: [CollabPhoto] {
        store.visiblePhotos.filter { photo in
            guard let author = store.person(photo.authorID) else { return false }
            let matchesFilter = filter == "For you" || author.realm.rawValue == filter || photo.tags.contains { $0.localizedCaseInsensitiveCompare(filter) == .orderedSame }
            // Photos and short videos only: the query matches captions and tags, never people (decision 55).
            let haystack = ([photo.caption] + photo.tags).joined(separator: " ")
            return matchesFilter && (query.isEmpty || haystack.localizedCaseInsensitiveContains(query))
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            KizukiTopBar(title: "Search", onSettings: { router.push(.settings) }, onInbox: { router.push(.inbox) })
            KizukiSearchField("Search photos & videos", text: $query).padding(.horizontal, 16)
            Text("Demo gallery · stock photography").font(KizukiTheme.mono(10)).foregroundStyle(KizukiTheme.babyBlueIcons)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { item in
                        Button { filter = item } label: {
                            Text(item).font(KizukiTheme.monoMedium(12)).padding(.horizontal, 14).frame(minHeight: 44)
                                .background(filter == item ? KizukiTheme.salmon : KizukiTheme.grey, in: Capsule())
                                .foregroundStyle(filter == item ? KizukiTheme.charcoal : KizukiTheme.cream)
                        }
                        .buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            ScrollView {
                if results.isEmpty {
                    KizukiEmptyState(title: "Nothing found", message: "Try another caption, tag or creative idea.")
                        .padding(KizukiTheme.pageInset)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3), spacing: 1) {
                        ForEach(results) { photo in
                            Button { router.push(.collabPhoto(photo.id)) } label: {
                                Artwork(seed: photo.artSeed, height: 140).overlay(alignment: .topLeading) {
                                    Text(photo.tags.first ?? "").font(KizukiTheme.mono(9)).padding(6)
                                }
                                .videoBadge(photo.durationLabel)
                            }
                            .buttonStyle(.plain).accessibilityLabel(photo.isVideo ? "Short video, \(photo.durationLabel ?? ""): \(photo.caption)" : "Collab photo: \(photo.caption)")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(KizukiTheme.charcoal).foregroundStyle(KizukiTheme.cream)
    }
}

/// Post viewer: image, caption, author, like, save, Report. Likes are private (OD-8); no comments (decision 25).
public struct CollabPhotoView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    let photoID: UUID
    @State private var liked = false
    @State private var saved = false
    public init(photoID: UUID) { self.photoID = photoID }

    public var body: some View {
        if let photo = store.photos.first(where: { $0.id == photoID }), let author = store.person(photo.authorID) {
            VStack(spacing: 0) {
                Artwork(seed: photo.artSeed, height: 420).videoBadge(photo.durationLabel, large: true)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button { router.push(.profile(author.id)) } label: { PersonRow(id: author.id, name: author.name, subtitle: "@\(author.handle) · 3 hours ago", portraitAsset: author.portraitAsset) }.buttonStyle(.plain)
                    }
                    Text(photo.caption).font(KizukiTheme.body(17))
                    HStack { ForEach(photo.tags, id: \.self) { KizukiChip($0) } }
                    HStack(spacing: 20) {
                        Button { liked.toggle() } label: { Image(systemName: liked ? "heart.fill" : "heart").foregroundStyle(liked ? KizukiTheme.orange : KizukiTheme.cream) }
                            .accessibilityLabel(liked ? "Unlike" : "Like")
                        Button { saved.toggle() } label: { Image(systemName: saved ? "bookmark.fill" : "bookmark") }.accessibilityLabel(saved ? "Unsave" : "Save")
                        Spacer()
                    }.font(.system(size: 22))
                }
                .padding(20)
                Spacer()
            }
            .background(KizukiTheme.charcoal).foregroundStyle(KizukiTheme.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu { Button(photo.isVideo ? "Report video" : "Report photo", systemImage: "flag") { router.sheet = .report(author.id) } } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityLabel("More")
                }
            }
        } else {
            ContentUnavailableView("Photo not found", systemImage: "photo")
        }
    }
}
#endif
