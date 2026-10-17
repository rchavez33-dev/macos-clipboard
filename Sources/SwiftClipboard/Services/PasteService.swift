import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
enum PasteService {
    /// Writes the item to the general pasteboard and returns the new change count.
    @discardableResult
    static func write(_ item: ClipItem) -> Int {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text, .link, .color:
            pb.setString(item.text ?? "", forType: .string)
        case .image:
            if let image = ImageCache.image(for: item) {
                pb.writeObjects([image])
            }
        case .file:
            pb.writeObjects((item.fileURLs ?? []) as [NSURL])
        }
        return pb.changeCount
    }

    /// Simulates ⌘V in the frontmost app. Requires Accessibility permission.
    static func sendPasteKeystroke() {
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

/// Global shortcut via Carbon (still the simplest sandbox-friendly API on macOS).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static var action: (() -> Void)?

    init(keyCode: Int = kVK_ANSI_V, modifiers: Int = cmdKey | shiftKey, action: @escaping () -> Void) {
        HotKey.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x5343_4C50), id: 1) // "SCLP"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
