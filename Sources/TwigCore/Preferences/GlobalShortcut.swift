import Foundation

/// Portable shortcut preferences; the platform adapter translates modifiers to Carbon.
public struct GlobalShortcut: Codable, Equatable, Sendable {
    public struct Modifiers: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let command = Self(rawValue: 1 << 0)
        public static let option = Self(rawValue: 1 << 1)
        public static let control = Self(rawValue: 1 << 2)
        public static let shift = Self(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public static let `default` = Self(keyCode: 49, modifiers: [.control, .option], keyLabel: "Space")

    public var isValid: Bool {
        keyCode < 128 && !modifiers.intersection([.command, .option, .control]).isEmpty
            && modifiers.subtracting([.command, .option, .control, .shift]).isEmpty
            && !keyLabel.isEmpty
    }

    public var displayName: String {
        (modifiers.contains(.control) ? "⌃" : "")
            + (modifiers.contains(.option) ? "⌥" : "")
            + (modifiers.contains(.shift) ? "⇧" : "")
            + (modifiers.contains(.command) ? "⌘" : "") + keyLabel
    }
}
