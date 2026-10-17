import SwiftUI

@MainActor
final class PanelState: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case all, pinned, text, link, color, image, file

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "Historial"
            case .pinned: "Fijados"
            case .text: "Texto"
            case .link: "Enlaces"
            case .color: "Colores"
            case .image: "Imágenes"
            case .file: "Archivos"
            }
        }

        var symbol: String {
            switch self {
            case .all: "clock"
            case .pinned: "pin"
            case .text: ClipKind.text.symbol
            case .link: ClipKind.link.symbol
            case .color: ClipKind.color.symbol
            case .image: ClipKind.image.symbol
            case .file: ClipKind.file.symbol
            }
        }

        var kind: ClipKind? { ClipKind(rawValue: rawValue) }
    }

    @Published var query = ""
    @Published var tab: Tab = .all
    @Published var selectedIndex = 0
    /// Changes every time the panel opens so the search field regains focus.
    @Published var focusToken = UUID()

    func reset() {
        query = ""
        selectedIndex = 0
        focusToken = UUID()
    }

    func move(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    func filtered(_ items: [ClipItem]) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { item in
            switch tab {
            case .all: break
            case .pinned: guard item.isPinned else { return false }
            default: guard item.kind == tab.kind else { return false }
            }
            return q.isEmpty || item.searchableText.lowercased().contains(q)
        }
    }
}
