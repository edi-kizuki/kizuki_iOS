import SwiftUI

public struct ProviderIcon: View {
    let assetName: String
    let size: CGFloat
    public init(_ assetName: String, size: CGFloat = 24) {
        self.assetName = assetName
        self.size = size
    }
    public var body: some View {
        Image(assetName, bundle: .module).renderingMode(.template)
            .resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
    public static func hasAsset(_ name: String) -> Bool { UIImage(named: name, in: .module, with: nil) != nil }
}

/// Kizuki's own vector icons and logos (template-rendering assets in `KizukiIcons.xcassets`, "Preserves Vector Data").
/// Traced from the Kizuki icon sheet in Figma.
public enum KizukiIcon: String, CaseIterable, Sendable {
    // Tab bar. One icon per tab.
    case tabHome = "TabHome", tabSearch = "TabSearch", tabSuki = "TabSuki", tabMyProjects = "TabMyProjects", tabProfile = "TabProfile"
    case wordmark = "KizukiWordmark", kMark = "KizukiKMark"
    case feedLogo = "KizukiFeedLogo"
    /// Figma nav-bar icons from the same header (`1312:8142`), and the Suki mascot (App (Copy) `614:9214`).
    case settings = "IconSettings", messages = "IconMessages", sukiMascot = "SukiMascot"

    public var image: Image { Image(rawValue, bundle: .module).renderingMode(self == .feedLogo ? .original : .template) }
    /// Used by tests to prove each asset ships in the bundle.
    public var uiImage: UIImage? { UIImage(named: rawValue, in: .module, with: nil) }
}

public enum KizukiIllustration: String, CaseIterable {
    case crewMedusa = "CrewMedusa"
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
