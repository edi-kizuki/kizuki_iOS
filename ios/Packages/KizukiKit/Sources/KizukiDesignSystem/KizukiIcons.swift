import SwiftUI

/// Kizuki's own vector icons and logos (template-rendering assets in `KizukiIcons.xcassets`, "Preserves Vector Data").
/// Sources and node ids: `docs/design/icons/README.md`.
public enum KizukiIcon: String, CaseIterable, Sendable {
    // Tab bar. One icon per tab; alternates live in docs/design/icons/sheet-traced.
    case tabHome = "TabHome", tabSearch = "TabSearch", tabSuki = "TabSuki", tabMyProjects = "TabMyProjects", tabProfile = "TabProfile"
    // Brand, from Figma "Playground (Copy)" concept_8.6.
    case wordmark = "KizukiWordmark", kMark = "KizukiKMark"
    /// The blue "k" from the Figma feed header (App (Copy) `1312:8143`). Keeps its own colours: blue K, dark eyes.
    case feedLogo = "KizukiFeedLogo"
    /// Figma nav-bar icons from the same header (`1312:8142`), and the Suki mascot (App (Copy) `614:9214`).
    case settings = "IconSettings", messages = "IconMessages", sukiMascot = "SukiMascot"

    /// Template images take the surrounding tint or foreground colour. The feed logo keeps its Figma colours.
    public var image: Image { Image(rawValue, bundle: .module).renderingMode(self == .feedLogo ? .original : .template) }
    /// Used by tests to prove each asset ships in the bundle.
    public var uiImage: UIImage? { UIImage(named: rawValue, in: .module, with: nil) }
}
