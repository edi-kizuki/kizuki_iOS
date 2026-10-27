import CoreText
import SwiftUI

/// Dark-only palette and type, taken from the Kizuki App Figma file.
public enum KizukiTheme {
    public static let charcoal = Color(hex: 0x1A1A1A)
    public static let cream = Color(hex: 0xF2EEE7)
    public static let grey = Color(hex: 0x333333)
    public static let darkGrey = Color(hex: 0x242424)
    public static let blue = Color(hex: 0x3F7BE2)
    public static let babyBlue = Color(hex: 0xC6CEDF)
    public static let babyBlueIcons = Color(hex: 0xB7C4DF)
    public static let orange = Color(hex: 0xE95833)
    public static let yellow = Color(hex: 0xEBAF41)
    public static let salmon = Color(hex: 0xFAC5B8)
    public static let ink = Color(hex: 0x371F1D)

    // Names kept from the foundation build.
    public static let canvas = charcoal
    public static let surface = darkGrey
    public static let accent = orange
    public static let spacing: CGFloat = 24
    public static let pageInset: CGFloat = 20
    public static let cardInset: CGFloat = 16
    public static let sectionGap: CGFloat = 24
    public static let border = babyBlueIcons.opacity(0.35)

    // Radii from the tokens doc.
    public static let cardRadius: CGFloat = 20
    public static let chipRadius: CGFloat = 15

    public static func title(_ size: CGFloat = 32) -> Font { KizukiFonts.font("LondrinaSolid-Regular", size, .title) }
    public static func titleBlack(_ size: CGFloat = 16) -> Font { KizukiFonts.font("LondrinaSolid-Black", size, .title) }
    public static func body(_ size: CGFloat = 16) -> Font { KizukiFonts.font("DMSans-9ptRegular_Regular", size, .body) }
    public static func bodyMedium(_ size: CGFloat = 16) -> Font { KizukiFonts.font("DMSans-9ptRegular_Medium", size, .body) }
    public static func bodyBold(_ size: CGFloat = 16) -> Font { KizukiFonts.font("DMSans-9ptRegular_Bold", size, .body) }
    public static func mono(_ size: CGFloat = 12) -> Font { KizukiFonts.font("DMMono-Regular", size, .caption) }
    public static func monoMedium(_ size: CGFloat = 12) -> Font { KizukiFonts.font("DMMono-Medium", size, .caption) }

    public enum PoppinsWeight: String, CaseIterable {
        case light = "Light", regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold", extraBold = "ExtraBold"
    }

    public static func poppins(_ size: CGFloat = 15, weight: PoppinsWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        KizukiFonts.font("Poppins-\(weight.rawValue)", size, style)
    }
}

public extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

/// Fonts ship inside the package bundle (OFL licences alongside), so they are registered at runtime.
public enum KizukiFonts {
    private static let files = ["LondrinaSolid-Regular", "LondrinaSolid-Black", "DMSans", "DMMono-Regular", "DMMono-Medium"]
        + KizukiTheme.PoppinsWeight.allCases.map { "Poppins-\($0.rawValue)" }
    private static let registered: Bool = {
        for file in files {
            if let url = Bundle.module.url(forResource: file, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return true
    }()
    public static func register() { _ = registered }
    static func font(_ name: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
        register()
        return .custom(name, size: size, relativeTo: style)
    }
}

public struct KizukiButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(KizukiTheme.cream)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .background(KizukiTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
