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
        Text(text).font(KizukiTheme.bodyMedium(12)).fixedSize(horizontal: false, vertical: true)
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
        FlowLayout(spacing: 6) {
            ForEach(reasons.prefix(2), id: \.self) { reason in
                Text(reason).font(KizukiTheme.mono(11)).fixedSize(horizontal: false, vertical: true)
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
            .frame(width: 44, height: 44).contentShape(Rectangle()).foregroundStyle(KizukiTheme.babyBlueIcons)
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

/// Bundled, credited stock photography for demo project and collab cards.
public struct Artwork: View {
    var seed: Int
    var height: CGFloat
    var title: String
    public init(seed: Int = 0, height: CGFloat = 220, title: String = "") { self.seed = seed; self.height = height; self.title = title }
    public static let stockAssets = ["StockFilm", "StockStudio", "StockPainting", "StockMicrophone", "StockBrushes", "StockWorkspace"]
    public static func hasStockAsset(named name: String) -> Bool { UIImage(named: name, in: .module, compatibleWith: nil) != nil }
    public var body: some View {
        Color.clear.frame(height: height).frame(maxWidth: .infinity)
            .overlay {
                Image(Self.stockAssets[Int(seed.magnitude % UInt(Self.stockAssets.count))], bundle: .module)
                    .resizable().scaledToFill()
            }
            .overlay(alignment: .bottomLeading) {
                if !title.isEmpty {
                    Text(title.uppercased()).font(KizukiTheme.title(30)).lineLimit(2)
                        .foregroundStyle(KizukiTheme.cream).padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.55))
                }
            }
            .clipped()
            .accessibilityElement().accessibilityLabel("Demo stock photograph")
    }
}

/// Explicit portrait asset with a deterministic Blobatar fallback.
public struct PersonAvatar: View {
    let id: UUID
    var size: CGFloat
    var portraitAsset: String?
    public init(_ id: UUID, size: CGFloat = 56, portraitAsset: String? = nil) { self.id = id; self.size = size; self.portraitAsset = portraitAsset }
    public var body: some View {
        Group {
            if let portraitAsset, UIImage(named: portraitAsset, in: .module, compatibleWith: nil) != nil {
                Image(portraitAsset, bundle: .module).resizable().scaledToFill()
            } else {
                ProfileAvatar(profileID: id)
            }
        }.frame(width: size, height: size)
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
            Text(title).font(KizukiTheme.poppins(12, relativeTo: .caption)).foregroundStyle(KizukiTheme.babyBlueIcons)
            TextField("", text: $text, prompt: Text(prompt.isEmpty ? title : prompt).foregroundStyle(KizukiTheme.cream.opacity(0.6))).font(KizukiTheme.poppins(15)).padding(.vertical, 10)
                .accessibilityLabel(title)
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
            Text(title).font(KizukiTheme.poppins(12, relativeTo: .caption)).foregroundStyle(KizukiTheme.babyBlueIcons)
            TextField("", text: $text, prompt: Text(title).foregroundStyle(KizukiTheme.cream.opacity(0.6)), axis: .vertical).lineLimit(3...6).font(KizukiTheme.poppins(15)).padding(12)
                .accessibilityLabel(title)
                .background(KizukiTheme.surface).overlay(Rectangle().stroke(KizukiTheme.border, lineWidth: 0.6))
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
        Text(text).font(KizukiTheme.title(24)).foregroundStyle(KizukiTheme.cream).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

public struct PageScroll<Content: View>: View {
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    @ViewBuilder var content: Content
    public init(spacing: CGFloat = KizukiTheme.sectionGap, horizontalPadding: CGFloat = KizukiTheme.pageInset, verticalPadding: CGFloat = KizukiTheme.pageInset, @ViewBuilder content: () -> Content) {
        self.spacing = spacing; self.horizontalPadding = horizontalPadding; self.verticalPadding = verticalPadding; self.content = content()
    }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) { content }
                .padding(.horizontal, horizontalPadding).padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(KizukiTheme.body()).background(KizukiTheme.charcoal).foregroundStyle(KizukiTheme.cream).scrollDismissesKeyboard(.interactively)
    }
}

public struct KizukiTopBar: View {
    let onInbox: () -> Void
    public init(onInbox: @escaping () -> Void) { self.onInbox = onInbox }
    public var body: some View {
        HStack {
            KizukiIcon.feedLogo.image.resizable().scaledToFit().frame(width: 22, height: 42.2346)
                .padding(.leading, 5.5).offset(y: -3).accessibilityLabel("Kizuki").accessibilityAddTraits(.isHeader)
            Spacer()
            KizukiIconButton(icon: .messages, label: "Messages", action: onInbox).offset(y: 7)
        }
        .padding(.leading, KizukiTheme.pageInset).padding(.trailing, 13).frame(minHeight: 62)
        .background(KizukiTheme.charcoal, in: UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
        .foregroundStyle(KizukiTheme.cream)
    }
}

public struct PersonRow: View {
    let id: UUID, name: String, subtitle: String
    var trailing: String
    var portraitAsset: String?
    public init(id: UUID, name: String, subtitle: String, trailing: String = "chevron.right", portraitAsset: String? = nil) {
        self.id = id; self.name = name; self.subtitle = subtitle; self.trailing = trailing; self.portraitAsset = portraitAsset
    }
    public var body: some View {
        HStack(spacing: 14) {
            PersonAvatar(id, size: 48, portraitAsset: portraitAsset)
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
    func kizukiPanel(edgeToEdge: Bool = false) -> some View {
        let radius = edgeToEdge ? 0 : KizukiTheme.cardRadius
        return padding(edgeToEdge ? KizukiTheme.pageInset : KizukiTheme.cardInset)
            .background(KizukiTheme.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(KizukiTheme.border, lineWidth: 0.6))
    }

    /// Card surface used on baby-blue canvases (tokens: feed section card radius 20).
    func kizukiCard(_ fill: Color = KizukiTheme.charcoal) -> some View {
        padding(KizukiTheme.pageInset).background(fill, in: RoundedRectangle(cornerRadius: KizukiTheme.cardRadius))
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
            subviews[i].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: ProposedViewSize(width: min(bounds.width, subviews[i].sizeThatFits(.unspecified).width), height: nil))
        }
    }
    private func arrange(width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: min(width, view.sizeThatFits(.unspecified).width), height: nil))
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
        .font(KizukiTheme.body(14)).padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 44).foregroundStyle(KizukiTheme.charcoal)
        .background(KizukiTheme.cream, in: RoundedRectangle(cornerRadius: 20))
    }
}

public struct KizukiEmptyState: View {
    let title: String
    let message: String
    public init(title: String, message: String) { self.title = title; self.message = message }
    public var body: some View {
        VStack(spacing: 12) {
            KizukiIcon.sukiMascot.image.resizable().scaledToFit().frame(height: 96)
                .foregroundStyle(KizukiTheme.orange).accessibilityHidden(true)
            Text(title).font(KizukiTheme.title(26))
            Text(message).font(KizukiTheme.body(14)).foregroundStyle(KizukiTheme.babyBlueIcons)
        }
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity).padding(.vertical, KizukiTheme.sectionGap).kizukiPanel()
        .accessibilityElement(children: .combine)
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
