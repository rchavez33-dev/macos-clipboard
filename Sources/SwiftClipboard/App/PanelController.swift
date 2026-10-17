import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Borderless, non-activating panel: it can take keyboard focus (for search)
/// without stealing "active app" status from the app you'll paste into.
final class ClipPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel = ClipPanel()
    private let store: ClipboardStore
    private let themes: ThemeManager
    private let monitor: ClipboardMonitor
    private let state = PanelState()

    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()
    private let panelHeight: CGFloat = 320

    init(store: ClipboardStore, themes: ThemeManager, monitor: ClipboardMonitor) {
        self.store = store
        self.themes = themes
        self.monitor = monitor
        super.init()

        let root = MainView(
            state: state,
            onPaste: { [weak self] in self?.paste($0) },
            onCopy: { [weak self] in self?.copy($0) },
            onClose: { [weak self] in self?.hide() }
        )
        .environmentObject(store)
        .environmentObject(themes)

        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host
        panel.delegate = self

        themes.$preset
            .sink { [weak self] preset in
                self?.panel.appearance = preset.theme.appearance.flatMap(NSAppearance.init(named:))
            }
            .store(in: &cancellables)
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }
        state.reset()

        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let target = NSRect(x: visible.minX + 8, y: visible.minY + 8,
                            width: visible.width - 16, height: panelHeight)
        var start = target
        start.origin.y -= 40

        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: Actions

    private func paste(_ item: ClipItem) {
        copy(item)
        hide()
        previousApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            PasteService.sendPasteKeystroke()
        }
    }

    private func copy(_ item: ClipItem) {
        let count = PasteService.write(item)
        monitor.ignore(changeCount: count)
        store.bumpToFront(item.id)
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns `true` when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let items = state.filtered(store.items)

        switch Int(event.keyCode) {
        case kVK_Escape:
            hide()
            return true
        case kVK_LeftArrow:
            state.move(-1, count: items.count)
            return true
        case kVK_RightArrow:
            state.move(1, count: items.count)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if items.indices.contains(state.selectedIndex) {
                paste(items[state.selectedIndex])
            }
            return true
        default:
            break
        }

        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let number = Int(chars), (1...9).contains(number) {
            if items.count >= number { paste(items[number - 1]) }
            return true
        }
        return false
    }
}
