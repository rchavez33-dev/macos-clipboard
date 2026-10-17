import SwiftUI

/// One clipboard card. Mirrors Paste's `ItemCell` composition:
/// HeaderView (title + date + app icon) → content view per type → Footer.
struct ItemCard: View {
    @EnvironmentObject private var themes: ThemeManager
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    @State private var hovering = false

    static let size = CGSize(width: 220, height: 230)

    var body: some View {
        let theme = themes.theme
        VStack(spacing: 0) {
            HeaderView(item: item, color: headerColor(theme))
            ItemContentView(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            FooterView(item: item, index: index)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                .strokeBorder(isSelected ? theme.selectionBorder : theme.cardBorder,
                              lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.28 : 0.12), radius: isSelected ? 10 : 4, y: 3)
        .scaleEffect(isSelected ? 1.0 : (hovering ? 0.985 : 0.97))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
    }

    private func headerColor(_ theme: Theme) -> Color {
        if theme.useAppIconColorForHeader,
           let ns = AppIconCache.dominantColor(for: item.sourceBundleID) {
            return Color(nsColor: ns)
        }
        return theme.headerColor(for: item.kind)
    }
}

// MARK: - Header

private struct HeaderView: View {
    @EnvironmentObject private var themes: ThemeManager
    let item: ClipItem
    let color: Color

    var body: some View {
        let theme = themes.theme
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.kind.title)
                        .font(.system(size: 13, weight: .semibold))
                    if item.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 10))
                    }
                }
                Text(item.date.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            if let icon = AppIconCache.icon(for: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .help(item.sourceAppName ?? "")
            } else {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .foregroundStyle(theme.headerText)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(color)
    }
}

// MARK: - Content per type

private struct ItemContentView: View {
    @EnvironmentObject private var themes: ThemeManager
    let item: ClipItem

    var body: some View {
        let theme = themes.theme
        switch item.kind {
        case .text:
            Text(item.text ?? "")
                .font(.system(size: 12))
                .foregroundStyle(theme.primaryText)
                .lineLimit(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)

        case .link:
            let url = URL(string: item.text ?? "")
            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(theme.linkColor)
                Text(url?.host() ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                Text(item.text ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.linkColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(10)

        case .color:
            let ns = ColorParser.parse(item.text ?? "") ?? .gray
            ZStack {
                Color(nsColor: ns)
                Text(item.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ns.isLight ? Color.black.opacity(0.8) : Color.white)
            }

        case .image:
            if let image = ImageCache.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: ItemCard.size.width)
                    .clipped()
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(theme.secondaryText)
            }

        case .file:
            let urls = item.fileURLs ?? []
            VStack(spacing: 8) {
                if let first = urls.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                        .resizable()
                        .frame(width: 64, height: 64)
                }
                Text(urls.map(\.lastPathComponent).joined(separator: ", "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
        }
    }
}

// MARK: - Footer

private struct FooterView: View {
    @EnvironmentObject private var themes: ThemeManager
    let item: ClipItem
    let index: Int

    var body: some View {
        let theme = themes.theme
        HStack {
            Text(item.footerText)
                .lineLimit(1)
            Spacer()
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.secondaryText.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 10)
        .frame(height: 28)
    }
}

private extension NSColor {
    var isLight: Bool {
        guard let c = usingColorSpace(.sRGB) else { return false }
        let luminance = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return luminance > 0.6 || c.alphaComponent < 0.4
    }
}
