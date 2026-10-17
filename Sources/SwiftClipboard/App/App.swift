import AppKit
import ApplicationServices
import Combine

@main
enum SwiftClipboardApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ClipboardStore()
    private let themes = ThemeManager()
    private let monitor = ClipboardMonitor()
    private var panel: PanelController!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(store: store, themes: themes, monitor: monitor)

        monitor.onNewItem = { [weak self] item in self?.store.add(item) }
        monitor.start()

        hotKey = HotKey { [weak self] in
            MainActor.assumeIsolated { self?.panel.toggle() }
        }

        setUpStatusItem()
        themes.$preset.sink { [weak self] _ in self?.rebuildMenu() }.store(in: &cancellables)

        if !AXIsProcessTrusted() {
            PasteService.requestAccessibility()
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                           accessibilityDescription: "SwiftClipboard")
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let show = NSMenuItem(title: "Mostrar historial", action: #selector(showPanel), keyEquivalent: "v")
        show.keyEquivalentModifierMask = [.command, .shift]
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())

        let themeItem = NSMenuItem(title: "Tema", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for preset in ThemePreset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            item.state = preset == themes.preset ? .on : .off
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let clear = NSMenuItem(title: "Limpiar historial (conserva fijados)",
                               action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showPanel() { panel.show() }

    @objc private func clearHistory() { store.clearUnpinned() }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = ThemePreset(rawValue: raw) else { return }
        themes.preset = preset
    }
}
