import SwiftUI

/// Kizuki's own vector icons and logos (template-rendering assets in `KizukiIcons.xcassets`, "Preserves Vector Data").
/// Traced from the Kizuki icon sheet in Figma.
public enum KizukiIcon: String, CaseIterable, Sendable {
    // Tab bar. One icon per tab.
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

public enum KizukiIllustration: String, CaseIterable {
    case dancingTrio = "DancingTrio", swirl = "SwirlPattern"
    case onboardingEyes = "OnboardingEyes", onboardingEye = "OnboardingEye", onboardingSuki = "OnboardingSuki"
    case onboardingCrest = "OnboardingCrest", onboardingWelcome = "OnboardingWelcome", onboardingAxolotl = "OnboardingAxolotl"
    case onboardingLoginPattern = "OnboardingLoginPattern", onboardingLoginPaper = "OnboardingLoginPaper", onboardingTrio = "OnboardingTrio"
    case onboardingPattern = "OnboardingPattern", onboardingCardEdge = "OnboardingCardEdge", onboardingTipEdge = "OnboardingTipEdge"
    public var image: Image { Image(rawValue, bundle: .module).renderingMode(.template) }
    public var originalImage: Image { Image(rawValue, bundle: .module).renderingMode(.original) }
    public var uiImage: UIImage? { UIImage(named: rawValue, in: .module, with: nil) }
}

public struct KizukiPatternBackground: View {
    let tint: Color
    public init(tint: Color = KizukiTheme.darkGrey) { self.tint = tint }
    public var body: some View {
        GeometryReader { geometry in
            KizukiIllustration.swirl.image.resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped().foregroundStyle(tint)
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
