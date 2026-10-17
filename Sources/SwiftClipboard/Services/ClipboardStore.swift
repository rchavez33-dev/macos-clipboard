import AppKit

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    let maxItems = 200

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftClipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    init() {
        load()
    }

    func add(_ item: ClipItem) {
        var newItem = item
        if let existing = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            // Same content copied again: keep pin state, move to front.
            newItem.isPinned = items[existing].isPinned
            items.remove(at: existing)
        }
        items.insert(newItem, at: 0)
        trim()
        save()
    }

    func bumpToFront(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.date = Date()
        items.insert(item, at: 0)
        save()
    }

    func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        save()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// Clears history but keeps pinned items.
    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        save()
    }

    private func trim() {
        var unpinned = 0
        items = items.filter { item in
            if item.isPinned { return true }
            unpinned += 1
            return unpinned <= maxItems
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        let snapshot = items
        let url = fileURL
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
