import KizukiCore
import KizukiDesignSystem
import KizukiTestSupport
import SwiftUI
import Testing
import UIKit
@testable import KizukiSukiFeature

@MainActor
struct CrewCardTests {
    @Test func crewMedusaShipsWithItsOriginalAspectRatioAndTransparency() throws {
        let image = try #require(KizukiIllustration.crewMedusa.uiImage?.cgImage)
        #expect(image.width == 190)
        #expect(image.height == 125)
        #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
    }

    @Test func crewCardGrowsForLongNamesAndAccessibilityXL() async throws {
        let store = AppStore(dependencies: FixtureBackend.dependencies())
        await store.load()
        var person = try #require(store.crew.first)
        func height(_ person: Person, size: DynamicTypeSize) -> CGFloat {
            let card = CrewCard(person: person, onMessage: {}, onProfile: {}, onRemove: {})
                .environment(\.dynamicTypeSize, size)
            let host = UIHostingController(rootView: card)
            return host.sizeThatFits(in: CGSize(width: 280, height: 10_000)).height
        }
        let regular = height(person, size: .large)
        person.name = "Alexandria-Cassandra Montgomery de la Cruz"
        person.roles = ["Multidisciplinary creative director and visual storyteller"]
        let long = height(person, size: .large)
        let accessible = height(person, size: .accessibility3)
        #expect(long > regular)
        #expect(accessible > long)
        #expect(accessible.isFinite && accessible < 2_000)
    }

}
