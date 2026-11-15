import AppKit
import Foundation

struct TimerSpec: Identifiable, Codable, Equatable {
    var id = UUID()
    var seconds: Int
    var tag: String?
}

struct TimerRecord: Identifiable, Codable {
    var id = UUID()
    var seconds: Int
    var tag: String?
    var startedAt: Date
    var endedAt: Date
}

struct TimerShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    static let createDefault = TimerShortcut(keyCode: 17, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    static let toggleDefault = TimerShortcut(keyCode: 35, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

    var title: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        let prefix = [
            flags.contains(.control) ? "⌃" : "",
            flags.contains(.option) ? "⌥" : "",
            flags.contains(.shift) ? "⇧" : "",
            flags.contains(.command) ? "⌘" : ""
        ].joined()
        let key = KeyCodeMap.characters[keyCode] ?? "Key \(keyCode)"
        return prefix + key.uppercased()
    }
}

enum KeyCodeMap {
    static let characters: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M", 49: "Space"
    ]
}

struct TimerPreferences: Codable {
    var soundName = "Glass"
    var volume = 0.7
    var notificationsEnabled = false
    var preventSleep = false
    var createShortcut = TimerShortcut.createDefault
    var toggleShortcut = TimerShortcut.toggleDefault
}

struct PersistedState: Codable {
    var preferences = TimerPreferences()
    var queue: [TimerSpec] = []
    var history: [TimerRecord] = []
    var loopEnabled = false
}

enum TimerInput {
    static func parse(_ input: String) -> TimerSpec? {
        let pieces = input.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let timeText = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = timeText.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count), parts.allSatisfy({ Int($0) != nil }) else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.allSatisfy({ $0 >= 0 }), values.dropLast().allSatisfy({ $0 < 60 }) else { return nil }

        let seconds: Int
        switch values.count {
        case 1: seconds = values[0]
        case 2: seconds = values[0] * 60 + values[1]
        default: seconds = values[0] * 3600 + values[1] * 60 + values[2]
        }
        guard seconds > 0, seconds <= 86_400 else { return nil }

        let tag = pieces.count == 2
            ? pieces[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            : ""
        return TimerSpec(seconds: seconds, tag: tag.isEmpty ? nil : tag)
    }
}

func durationText(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainder = seconds % 60
    return hours > 0
        ? String(format: "%02d:%02d:%02d", hours, minutes, remainder)
        : String(format: "%02d:%02d", minutes, remainder)
}