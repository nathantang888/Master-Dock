import Foundation
import Carbon.HIToolbox

/// System-wide keyboard shortcuts using macOS's hot key service. Unlike watching every key
/// press, this needs no Accessibility permission and only wakes the app when the exact
/// shortcut is pressed.
public final class GlobalHotKeys {
    public static let shared = GlobalHotKeys()

    public struct Shortcut: Equatable {
        public let keyCode: UInt32
        public let modifiers: UInt32
        public let display: String
    }

    /// Shift + Command + Space: opens or closes the dock. Not used by macOS itself
    /// (Spotlight is Command + Space, emoji is Control + Command + Space).
    public static let toggleDock = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey), display: "⇧⌘Space")
    /// Option + Shift + Command + Space: opens voice mode.
    public static let voiceMode = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey | optionKey), display: "⌥⇧⌘Space")

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private static let signature: OSType = 0x4D44_4B59 // "MDKY"

    private init() {}

    /// Registers a shortcut. Returns false if another app already owns it.
    @discardableResult
    public func register(id: UInt32, _ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        unregister(id: id)
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        handlers[id] = action
        return true
    }

    public func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers[id] = nil
    }

    public func unregisterAll() {
        for id in Array(refs.keys) { unregister(id: id) }
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let id = hotKeyID.id
            DispatchQueue.main.async { GlobalHotKeys.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
