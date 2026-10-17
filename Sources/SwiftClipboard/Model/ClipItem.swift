import AppKit
import CryptoKit

enum ClipKind: String, Codable, CaseIterable, Hashable {
    case text, link, color, image, file

    var title: String {
        switch self {
        case .text: "Texto"
        case .link: "Enlace"
        case .color: "Color"
        case .image: "Imagen"
        case .file: "Archivo"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .color: "paintpalette"
        case .image: "photo"
        case .file: "doc"
        }
    }
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var imageData: Data?
    var fileURLs: [URL]?
    var sourceAppName: String?
    var sourceBundleID: String?
    var date = Date()
    var isPinned = false
    /// Stable content identity used to de-duplicate repeated copies.
    var fingerprint: String

    init(kind: ClipKind, text: String? = nil, imageData: Data? = nil, fileURLs: [URL]? = nil,
         source: NSRunningApplication? = nil) {
        self.kind = kind
        self.text = text
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.sourceAppName = source?.localizedName
        self.sourceBundleID = source?.bundleIdentifier
        switch kind {
        case .text, .link, .color:
            fingerprint = "\(kind.rawValue):\(text ?? "")"
        case .file:
            fingerprint = "file:" + (fileURLs ?? []).map(\.path).joined(separator: "|")
        case .image:
            fingerprint = "image:" + SHA256.hash(data: imageData ?? Data())
                .map { String(format: "%02x", $0) }.joined()
        }
    }

    var searchableText: String {
        [text, fileURLs?.map(\.lastPathComponent).joined(separator: " "), sourceAppName, kind.title]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    @MainActor
    var footerText: String {
        switch kind {
        case .text:
            let n = text?.count ?? 0
            return "\(n) carácter\(n == 1 ? "" : "es")"
        case .link:
            return URL(string: text ?? "")?.host() ?? "Enlace"
        case .color:
            return text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Color"
        case .image:
            if let img = ImageCache.image(for: self) {
                return "\(Int(img.size.width)) × \(Int(img.size.height))"
            }
            return "Imagen"
        case .file:
            let n = fileURLs?.count ?? 0
            return "\(n) archivo\(n == 1 ? "" : "s")"
        }
    }
}

// MARK: - Classification

extension ClipItem {
    static func fromString(_ string: String, source: NSRunningApplication?) -> ClipItem {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind: ClipKind
        if ColorParser.parse(trimmed) != nil {
            kind = .color
        } else if isLink(trimmed) {
            kind = .link
        } else {
            kind = .text
        }
        return ClipItem(kind: kind, text: string, source: source)
    }

    private static func isLink(_ s: String) -> Bool {
        guard !s.contains(where: \.isWhitespace),
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host() != nil
        else { return false }
        return true
    }
}

enum ColorParser {
    private static let rgbRegex = try! NSRegularExpression(
        pattern: #"^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+)\s*)?\)$"#,
        options: .caseInsensitive
    )

    static func parse(_ raw: String) -> NSColor? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { return parseHex(String(s.dropFirst())) }

        let range = NSRange(s.startIndex..., in: s)
        guard let m = rgbRegex.firstMatch(in: s, range: range) else { return nil }
        func group(_ i: Int) -> String? {
            Range(m.range(at: i), in: s).map { String(s[$0]) }
        }
        guard let r = group(1).flatMap(Double.init), let g = group(2).flatMap(Double.init),
              let b = group(3).flatMap(Double.init), r <= 255, g <= 255, b <= 255
        else { return nil }
        let a = group(4).flatMap(Double.init) ?? 1
        return NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: min(max(a, 0), 1))
    }

    private static func parseHex(_ hex: String) -> NSColor? {
        guard [3, 6, 8].contains(hex.count), let value = UInt64(hex, radix: 16) else { return nil }
        switch hex.count {
        case 3:
            let r = (value >> 8) & 0xF, g = (value >> 4) & 0xF, b = value & 0xF
            return NSColor(srgbRed: CGFloat(r * 17) / 255, green: CGFloat(g * 17) / 255,
                           blue: CGFloat(b * 17) / 255, alpha: 1)
        case 6:
            return NSColor(hex: UInt32(value))
        default:
            return NSColor(hex: UInt32(value >> 8), alpha: CGFloat(value & 0xFF) / 255)
        }
    }
}

// MARK: - Caches

@MainActor
enum ImageCache {
    private static let cache = NSCache<NSUUID, NSImage>()

    static func image(for item: ClipItem) -> NSImage? {
        let key = item.id as NSUUID
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = item.imageData, let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]
    private static var colors: [String: NSColor] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = icons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }

    /// Average color of the app icon, clamped so white header text stays legible
    /// (this mimics how Paste tints each card header by its source app).
    static func dominantColor(for bundleID: String?) -> NSColor? {
        guard let bundleID else { return nil }
        if let c = colors[bundleID] { return c }
        guard let icon = icon(for: bundleID),
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        icon.draw(in: NSRect(x: 0, y: 0, width: 1, height: 1), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let avg = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        avg.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let color = NSColor(hue: h, saturation: min(s * 1.3, 1), brightness: min(max(b, 0.45), 0.75), alpha: 1)
        colors[bundleID] = color
        return color
    }
}
