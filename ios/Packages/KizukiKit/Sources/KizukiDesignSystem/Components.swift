import SwiftUI

/// Orange button with a cream border and the 4 pt hard offset shadow (tokens: primary button).
public struct PrimaryButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var color: Color
    var textColor: Color
    let action: () -> Void
    public init(_ title: String, color: Color = KizukiTheme.orange, textColor: Color = KizukiTheme.cream, action: @escaping () -> Void) {
        self.title = title; self.color = color; self.textColor = textColor; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Text(title.uppercased()).font(KizukiTheme.titleBlack(18)).tracking(1.1)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(isEnabled ? textColor : KizukiTheme.babyBlueIcons.opacity(0.6))
                .background(isEnabled ? color : KizukiTheme.grey)
                .overlay(Rectangle().stroke(isEnabled ? KizukiTheme.cream : KizukiTheme.grey, lineWidth: 1))
                // The offset shadow is a separate layer so the label is never shadowed.
                .background(alignment: .topLeading) {
                    Rectangle().fill(KizukiTheme.cream.opacity(isEnabled ? 0.8 : 0)).offset(x: 4, y: 4)
                }
        }
        .buttonStyle(.plain).padding(.trailing, 4).padding(.bottom, 4)
    }
}

public struct OutlineButton: View {
    let title: String
    let action: () -> Void
    public init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    public var body: some View {
        Button(action: action) {
            Text(title).font(KizukiTheme.mono(13)).frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(KizukiTheme.cream)
                .overlay(Capsule().stroke(KizukiTheme.babyBlueIcons.opacity(0.6), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

public struct KizukiChip: View {
    let text: String
    var selected: Bool
    public init(_ text: String, selected: Bool = false) { self.text = text; self.selected = selected }
    public var body: some View {
        Text(text).font(KizukiTheme.mono(12)).lineLimit(1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(selected ? KizukiTheme.cream : KizukiTheme.babyBlue)
            .background(selected ? KizukiTheme.blue : KizukiTheme.charcoal, in: Capsule())
            .overlay(Capsule().stroke(selected ? KizukiTheme.blue : KizukiTheme.babyBlueIcons.opacity(0.55), lineWidth: 1))
    }
}

/// Match-reason chips ("In your city", "Shared taste"). Max two, rule-based reasons only.
public struct ReasonChips: View {
    let reasons: [String]
    public init(_ reasons: [String]) { self.reasons = reasons }
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(reasons.prefix(2), id: \.self) { reason in
                Text(reason).font(KizukiTheme.mono(10)).lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(KizukiTheme.charcoal).background(KizukiTheme.babyBlue, in: Capsule())
            }
        }
    }
}

public struct KizukiIconButton: View {
    let symbol: String?, icon: KizukiIcon?, label: String
    let action: () -> Void
    public init(symbol: String, label: String, action: @escaping () -> Void) { self.symbol = symbol; self.icon = nil; self.label = label; self.action = action }
    /// A Kizuki vector icon (24 pt glyph in a 44 pt target).
    public init(icon: KizukiIcon, label: String, action: @escaping () -> Void) { self.symbol = nil; self.icon = icon; self.label = label; self.action = action }
    public var body: some View {
        Button(action: action) {
            Group {
                if let icon { icon.image.resizable().scaledToFit().frame(width: 24, height: 24) }
                else if let symbol { Image(systemName: symbol).font(.system(size: 22)) }
            }
            .frame(width: 44, height: 44).foregroundStyle(KizukiTheme.babyBlueIcons)
        }.accessibilityLabel(label)
    }
}

/// Hand-drawn feel: a slightly zigzag top and bottom edge.
public struct RoughShape: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path {
        var p = Path(); let step: CGFloat = 8
        let count = max(1, Int(r.width / step))
        p.move(to: CGPoint(x: 1, y: 2))
        for i in 0...count { p.addLine(to: CGPoint(x: min(CGFloat(i) * step, r.width - 1), y: i % 2 == 0 ? 2 : 0)) }
        p.addLine(to: CGPoint(x: r.width - 1, y: r.height - 2))
        for i in (0...count).reversed() { p.addLine(to: CGPoint(x: min(CGFloat(i) * step, r.width - 1), y: r.height - (i % 2 == 0 ? 2 : 0))) }
        p.closeSubpath()
        return p
    }
}

/// Gradient + SF Symbol placeholder for photos (no external images in the prototype).
public struct Artwork: View {
    var seed: Int
    var height: CGFloat
    var title: String
    public init(seed: Int = 0, height: CGFloat = 220, title: String = "") { self.seed = seed; self.height = height; self.title = title }
    private var colors: [Color] {
        let t = KizukiTheme.self
        return [[t.ink, t.orange], [t.blue, t.charcoal], [t.babyBlue, t.blue], [t.ink, t.salmon], [t.grey, t.yellow]][abs(seed) % 5]
    }
    private var symbol: String { ["waveform", "camera.aperture", "film.stack", "paintbrush.pointed", "pianokeys", "sparkles"][abs(seed) % 6] }
    public var body: some View {
        // The overlay is sized by the clear base, so decorative circles never widen the layout.
        Color.clear.frame(height: height).frame(maxWidth: .infinity)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().stroke(KizukiTheme.cream.opacity(0.22), lineWidth: 1).frame(width: 200, height: 200).offset(x: 120, y: -50)
                    Circle().stroke(KizukiTheme.cream.opacity(0.15), lineWidth: 18).frame(width: 160, height: 160).offset(x: -30, y: 60)
                    Image(systemName: symbol).font(.system(size: min(height * 0.28, 70), weight: .ultraLight))
                        .foregroundStyle(KizukiTheme.cream.opacity(0.75)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !title.isEmpty {
                        Text(title.uppercased()).font(KizukiTheme.title(30)).lineLimit(2).foregroundStyle(KizukiTheme.cream).padding(16)
                    }
                }
            }
            .clipped()
            .accessibilityElement().accessibilityLabel("Placeholder image")
    }
}

/// Deterministic Blobatar from the person's id, on a soft disc.
public struct PersonAvatar: View {
    let id: UUID
    var size: CGFloat
    public init(_ id: UUID, size: CGFloat = 56) { self.id = id; self.size = size }
    public var body: some View {
        ProfileAvatar(profileID: id).frame(width: size, height: size)
            .background(KizukiTheme.babyBlue.opacity(0.18), in: Circle()).clipShape(Circle())
    }
}

public struct KizukiField: View {
    let title: String
    @Binding var text: String
    var prompt: String
    public init(_ title: String, text: Binding<String>, prompt: String = "") { self.title = title; self._text = text; self.prompt = prompt }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            TextField("", text: $text, prompt: Text(prompt.isEmpty ? title : prompt).foregroundStyle(KizukiTheme.cream.opacity(0.4))).font(KizukiTheme.body(16)).padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(KizukiTheme.cream.opacity(0.3)).frame(height: 0.6) }
        }
    }
}

public struct KizukiTextArea: View {
    let title: String
    @Binding var text: String
    public init(_ title: String, text: Binding<String>) { self.title = title; self._text = text }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(KizukiTheme.mono(11)).foregroundStyle(KizukiTheme.babyBlueIcons)
            TextField("", text: $text, prompt: Text(title).foregroundStyle(KizukiTheme.cream.opacity(0.4)), axis: .vertical).lineLimit(3...6).font(KizukiTheme.body(15)).padding(12)
                .background(KizukiTheme.grey.opacity(0.5)).overlay(Rectangle().stroke(KizukiTheme.babyBlueIcons.opacity(0.4), lineWidth: 0.6))
        }
    }
}

/// Selectable row with a rough border, used by every single-choice question.
public struct ChoiceRow: View {
    let label: String
    var selected: Bool
    var detail: String?
    let action: () -> Void
    public init(_ label: String, selected: Bool, detail: String? = nil, action: @escaping () -> Void) {
        self.label = label; self.selected = selected; self.detail = detail; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(KizukiTheme.mono(15)).multilineTextAlignment(.leading)
                    if let detail { Text(detail).font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons) }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? KizukiTheme.orange : KizukiTheme.babyBlueIcons)
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 60)
            .background(KizukiTheme.grey.opacity(0.4)).clipShape(RoughShape())
            .overlay(RoughShape().stroke(selected ? KizukiTheme.orange : KizukiTheme.babyBlueIcons, lineWidth: 1.2))
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

public struct SectionTitle: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text).font(KizukiTheme.title(25)).foregroundStyle(KizukiTheme.cream).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

public struct PageScroll<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content
    public init(spacing: CGFloat = 24, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KizukiTheme.charcoal).foregroundStyle(KizukiTheme.cream).scrollDismissesKeyboard(.interactively)
    }
}

/// Top bar with the blue K (or a page title), settings gear and DM icon (decision 19).
public struct KizukiTopBar: View {
    let title: String
    let onSettings: () -> Void
    let onInbox: () -> Void
    public init(title: String = "", onSettings: @escaping () -> Void, onInbox: @escaping () -> Void) {
        self.title = title; self.onSettings = onSettings; self.onInbox = onInbox
    }
    public var body: some View {
        HStack {
            if title.isEmpty {
                // Figma "Feed / Discovery Page" header: the 22 x 42 blue k at the left, 5.5 pt further in than the title.
                KizukiIcon.feedLogo.image.resizable().scaledToFit().frame(width: 22, height: 42.2346)
                    .padding(.leading, 5.5).offset(y: -3).accessibilityLabel("Kizuki").accessibilityAddTraits(.isHeader)
            } else {
                Text(title).font(KizukiTheme.title(32)).accessibilityAddTraits(.isHeader)
            }
            Spacer()
            // Figma: two 24 pt icons 20 pt apart (two 44 pt targets side by side), sitting slightly below the logo's centre line.
            HStack(spacing: 0) {
                KizukiIconButton(icon: .settings, label: "Settings", action: onSettings)
                KizukiIconButton(icon: .messages, label: "Messages", action: onInbox)
            }
            .offset(y: 7)
        }
        .padding(.leading, 20).padding(.trailing, 13).frame(height: 62)
        .background(KizukiTheme.charcoal, in: UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
        .foregroundStyle(KizukiTheme.cream)
    }
}

public struct PersonRow: View {
    let id: UUID, name: String, subtitle: String
    var trailing: String
    public init(id: UUID, name: String, subtitle: String, trailing: String = "chevron.right") {
        self.id = id; self.name = name; self.subtitle = subtitle; self.trailing = trailing
    }
    public var body: some View {
        HStack(spacing: 14) {
            PersonAvatar(id, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(KizukiTheme.bodyMedium(17))
                Text(subtitle).font(KizukiTheme.body(12)).foregroundStyle(KizukiTheme.babyBlueIcons).lineLimit(2)
            }
            Spacer()
            Image(systemName: trailing).foregroundStyle(KizukiTheme.babyBlueIcons)
        }
        .frame(minHeight: 60).contentShape(Rectangle())
    }
}

public extension View {
    /// Card surface used on baby-blue canvases (tokens: feed section card radius 20).
    func kizukiCard(_ fill: Color = KizukiTheme.charcoal) -> some View {
        padding(20).background(fill, in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
    }
}

/// Wrapping row layout for chips.
public struct FlowLayout: Layout {
    var spacing: CGFloat
    public init(spacing: CGFloat = 8) { self.spacing = spacing }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 320, subviews).size
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, point) in arrange(width: bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    private func arrange(width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height); maxX = max(maxX, x - spacing)
        }
        return (points, CGSize(width: maxX, height: y + rowHeight))
    }
}

public struct KizukiSearchField: View {
    @Binding var text: String
    let placeholder: String
    public init(_ placeholder: String, text: Binding<String>) { self.placeholder = placeholder; self._text = text }
    public var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(KizukiTheme.charcoal.opacity(0.5)))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 32, height: 32) }.accessibilityLabel("Clear search")
            }
        }
        .font(KizukiTheme.body(14)).padding(.horizontal, 14).frame(height: 40).foregroundStyle(KizukiTheme.charcoal)
        .background(KizukiTheme.cream, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: Short-video placeholder badge (decision 55)

public extension View {
    /// Draws a play badge and a duration over a placeholder tile. `large` is for the post viewer.
    @ViewBuilder func videoBadge(_ durationLabel: String?, large: Bool = false) -> some View {
        if let durationLabel {
            overlay {
                Image(systemName: "play.fill").font(.system(size: large ? 30 : 13, weight: .bold)).foregroundStyle(KizukiTheme.cream)
                    .frame(width: large ? 72 : 30, height: large ? 72 : 30)
                    .background(KizukiTheme.charcoal.opacity(0.62), in: Circle())
                    .overlay(Circle().stroke(KizukiTheme.cream.opacity(0.8), lineWidth: 1))
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(durationLabel).font(KizukiTheme.mono(large ? 13 : 10)).foregroundStyle(KizukiTheme.cream)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(KizukiTheme.charcoal.opacity(0.7), in: Capsule())
                    .padding(large ? 12 : 5).accessibilityHidden(true)
            }
        } else {
            self
        }
    }

    /// "Remove from Crew" confirmation. Separate from Block: it ends the connection and closes the chat, nothing more.
    func removeFromCrewConfirmation(isPresented: Binding<Bool>, name: String, onConfirm: @escaping () -> Void) -> some View {
        confirmationDialog("Remove \(name) from your Crew?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Remove from Crew", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The chat closes. \(name) isn’t blocked and can send a new request.")
        }
    }
}
