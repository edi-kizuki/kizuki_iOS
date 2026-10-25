import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Maps only an opaque profile ID to a bundled, locally generated Blobatar PNG.
/// A finite palette deliberately avoids an SVG runtime and external hosting.
public enum AvatarCatalog {
    public static let count = 32
    public static func resourceName(for profileID: UUID) -> String {
        let digest = SHA256.hash(data: Data(profileID.uuidString.lowercased().utf8))
        let index = Int(Array(digest)[0]) % count
        return String(format: "avatar-%02d", index)
    }
    public static func resourceURL(for profileID: UUID) -> URL? {
        Bundle.module.url(forResource: resourceName(for: profileID), withExtension: "png")
    }
}

public struct ProfileAvatar: View {
    private let profileID: UUID
    public init(profileID: UUID) { self.profileID = profileID }
    public var body: some View {
        Group {
            if let url = AvatarCatalog.resourceURL(for: profileID), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
            } else {
                // Deterministic offline fallback if a resource cannot be loaded.
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(KizukiTheme.accent)
            }
        }
        .accessibilityHidden(true)
    }
}
