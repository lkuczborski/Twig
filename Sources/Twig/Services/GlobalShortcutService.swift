import AppKit
import Carbon
import TwigCore

/// Carbon registers one shortcut without monitoring typing or requesting Accessibility access.
@MainActor
final class GlobalShortcutService {
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var current: GlobalShortcut?
    private var identifier: UInt32 = 0
    private let action: () -> Void
    private static let signature: UInt32 = 0x54574947 // TWIG

    init(action: @escaping () -> Void) {
        self.action = action
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let service = Unmanaged<GlobalShortcutService>.fromOpaque(context).takeUnretainedValue()
                var id = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                      id.signature == GlobalShortcutService.signature, id.id == service.identifier,
                      service.hotKey != nil else {
                    return OSStatus(eventNotHandledErr)
                }
                service.action()
                return noErr
            }
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// Register first, so a conflict leaves the previous shortcut working.
    func configure(_ shortcut: GlobalShortcut?) -> String? {
        if shortcut == current { return nil }
        guard let shortcut else {
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = nil
            current = nil
            return nil
        }
        guard shortcut.isValid, handler != nil else { return "The global shortcut could not be registered." }
        var modifiers: UInt32 = 0
        if shortcut.modifiers.contains(.command) { modifiers |= UInt32(cmdKey) }
        if shortcut.modifiers.contains(.option) { modifiers |= UInt32(optionKey) }
        if shortcut.modifiers.contains(.control) { modifiers |= UInt32(controlKey) }
        if shortcut.modifiers.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let next = identifier &+ 1
        var replacement: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, modifiers,
            EventHotKeyID(signature: Self.signature, id: next), GetApplicationEventTarget(), 0, &replacement)
        guard status == noErr else {
            return "That shortcut is unavailable. Choose another key combination."
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
        identifier = next
        current = shortcut
        return nil
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        current = nil
    }
}
