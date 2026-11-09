import SwiftUI

enum VikingTheme {
    static let background = Color(red: 0.055, green: 0.060, blue: 0.057)
    static let surface = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let raised = Color(red: 0.20, green: 0.21, blue: 0.18)
    static let ink = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let secondary = Color(red: 0.72, green: 0.73, blue: 0.66)
    static let accent = Color(red: 0.89, green: 0.72, blue: 0.43)
    static let ember = Color(red: 0.94, green: 0.50, blue: 0.34)
    static let success = Color(red: 0.55, green: 0.80, blue: 0.69)
    static let danger = Color(red: 1, green: 0.55, blue: 0.48)
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "PaperMono-Regular" : "PaperMono-Medium", size: size, relativeTo: .body)
    }
}
struct VikingBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            VikingTheme.background
            if !reduceTransparency { DitherSurface() }
            RadialGradient(colors: [VikingTheme.accent.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 700)
            RadialGradient(colors: [VikingTheme.success.opacity(0.055), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 600)
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}
private struct VikingGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency { content.background(VikingTheme.raised, in: RoundedRectangle(cornerRadius: 22)) }
        else if #available(iOS 26, *) { content.background { DitherSurface(placement: .edge).clipShape(RoundedRectangle(cornerRadius: 22)) }.glassEffect(.regular.tint(VikingTheme.surface.opacity(0.32)), in: RoundedRectangle(cornerRadius: 22)) }
        else { content.background { DitherSurface(placement: .edge).clipShape(RoundedRectangle(cornerRadius: 22)) }.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22)) }
    }
}
private struct VikingPrimaryModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) { content.fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center).buttonStyle(.glassProminent).tint(VikingTheme.accent).foregroundStyle(VikingTheme.background).controlSize(.large) }
        else { content.buttonStyle(.borderedProminent).tint(VikingTheme.accent).foregroundStyle(VikingTheme.background).controlSize(.large) }
    }
}
private struct VikingSecondaryModifier: ViewModifier {
    var compact = false
    var icon = false
    func body(content: Content) -> some View {
        if #available(iOS 26, *) { content.fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center).buttonStyle(.glass).buttonBorderShape(icon ? .circle : .capsule).tint(VikingTheme.accent).controlSize(compact ? .regular : .large) }
        else { content.buttonStyle(.bordered).buttonBorderShape(icon ? .circle : .capsule).tint(VikingTheme.accent).controlSize(compact ? .regular : .large) }
    }
}
extension View {
    func vikingGlass() -> some View { modifier(VikingGlassModifier()) }
    func vikingPrimary() -> some View { modifier(VikingPrimaryModifier()) }
    func vikingSecondary(compact: Bool = false, icon: Bool = false) -> some View { modifier(VikingSecondaryModifier(compact: compact, icon: icon)) }
    func vikingList() -> some View {
        self.scrollContentBackground(.hidden).listStyle(.insetGrouped).background { VikingBackdrop() }
            .foregroundStyle(VikingTheme.ink).tint(VikingTheme.accent)
    }
}
struct VikingPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View { content().padding(20).frame(maxWidth: .infinity, alignment: .leading).vikingGlass() }
}
struct VikingScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) { content() }.padding(20).frame(maxWidth: 960).frame(maxWidth: .infinity) }
            .background { VikingBackdrop() }.foregroundStyle(VikingTheme.ink).scrollDismissesKeyboard(.interactively)
    }
}
struct VikingPageHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(VikingTheme.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(VikingTheme.font(27, weight: .medium))
                if !subtitle.isEmpty { Text(subtitle).font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary).lineSpacing(4) }
            }
        }.padding(.vertical, 12)
    }
}
struct VikingActionRow: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 22, weight: .light)).frame(minWidth: 28).foregroundStyle(VikingTheme.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(VikingTheme.font(16, weight: .medium)).foregroundStyle(VikingTheme.ink).fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty { Text(subtitle).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
            }.layoutPriority(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(VikingTheme.secondary).accessibilityHidden(true)
        }.padding(.horizontal, 18).padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).background { if !reduceTransparency { DitherSurface(placement: .edge).opacity(0.5) } }.contentShape(Rectangle())
    }
}
struct VikingEmptyState: View {
    let title: String
    let message: String
    var symbol = "sailboat"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: symbol).font(.system(size: 38, weight: .ultraLight)).foregroundStyle(VikingTheme.accent).accessibilityHidden(true)
            Text(title).font(VikingTheme.font(23, weight: .medium))
            if !message.isEmpty { Text(message).font(VikingTheme.font(14)).foregroundStyle(VikingTheme.secondary).lineSpacing(4) }
            if let actionTitle, let action { Button(actionTitle, action: action).vikingPrimary() }
        }.padding(.vertical, 20).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VikingFormSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) { self.title = title; self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title { Text(title).font(VikingTheme.font(17, weight: .medium)) }
            VikingPanel { VStack(alignment: .leading, spacing: 20) { content() } }
        }
    }
}
