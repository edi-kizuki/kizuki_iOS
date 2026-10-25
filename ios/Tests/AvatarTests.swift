import Foundation
import KizukiDesignSystem
import Testing
import UIKit

struct AvatarTests {
    @Test func deterministicAndBundled() throws {
        let id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        #expect(AvatarCatalog.resourceName(for: id) == "avatar-26")
        let url = try #require(AvatarCatalog.resourceURL(for: id))
        let data = try Data(contentsOf: url)
        #expect(data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]))
        let resources = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        let avatars = resources.filter { $0.pathExtension == "png" && $0.lastPathComponent.hasPrefix("avatar-") }
        #expect(avatars.count == 32)
        for avatar in avatars {
            let image = try #require(UIImage(contentsOfFile: avatar.path))
            #expect(image.size.width == 256 && image.size.height == 256)
        }
    }

    @Test func distributesOpaqueIDs() {
        let names = (0..<256).compactMap { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", $0)) }
            .map(AvatarCatalog.resourceName)
        #expect(Set(names).count > 24)
        #expect(names.allSatisfy { $0.hasPrefix("avatar-") })
    }
}
