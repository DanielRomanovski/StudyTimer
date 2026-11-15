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

struct TimerPreset: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var timers: [TimerSpec]
    var loopEnabled: Bool
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
    var customSoundFilename: String?
    var volume = 0.7
    var notificationsEnabled = false
    var preventSleep = false
    var loopCompletionSound = false
    var createShortcut = TimerShortcut.createDefault
    var toggleShortcut = TimerShortcut.toggleDefault

    private enum CodingKeys: String, CodingKey {
        case soundName, customSoundFilename, volume, notificationsEnabled, preventSleep
        case loopCompletionSound, createShortcut, toggleShortcut
    }

    init() {
        soundName = "Glass"
        customSoundFilename = nil
        volume = 0.7
        notificationsEnabled = false
        preventSleep = false
        loopCompletionSound = false
        createShortcut = .createDefault
        toggleShortcut = .toggleDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? "Glass"
        customSoundFilename = try container.decodeIfPresent(String.self, forKey: .customSoundFilename)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 0.7
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        preventSleep = try container.decodeIfPresent(Bool.self, forKey: .preventSleep) ?? false
        loopCompletionSound = try container.decodeIfPresent(Bool.self, forKey: .loopCompletionSound) ?? false
        createShortcut = try container.decodeIfPresent(TimerShortcut.self, forKey: .createShortcut) ?? .createDefault
        toggleShortcut = try container.decodeIfPresent(TimerShortcut.self, forKey: .toggleShortcut) ?? .toggleDefault
    }
}

struct PersistedState: Codable {
    var preferences = TimerPreferences()
    var queue: [TimerSpec] = []
    var history: [TimerRecord] = []
    var loopEnabled = false
    var presets: [TimerPreset] = []
    var activeTimer: TimerSpec?
    var remainingSeconds = 0
    var isRunning = false
    var activeStartedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case preferences, queue, history, loopEnabled, presets
        case activeTimer, remainingSeconds, isRunning, activeStartedAt
    }

    init(
        preferences: TimerPreferences = TimerPreferences(),
        queue: [TimerSpec] = [],
        history: [TimerRecord] = [],
        loopEnabled: Bool = false,
        presets: [TimerPreset] = [],
        activeTimer: TimerSpec? = nil,
        remainingSeconds: Int = 0,
        isRunning: Bool = false,
        activeStartedAt: Date? = nil
    ) {
        self.preferences = preferences
        self.queue = queue
        self.history = history
        self.loopEnabled = loopEnabled
        self.presets = presets
        self.activeTimer = activeTimer
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.activeStartedAt = activeStartedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try container.decodeIfPresent(TimerPreferences.self, forKey: .preferences) ?? TimerPreferences()
        queue = try container.decodeIfPresent([TimerSpec].self, forKey: .queue) ?? []
        history = try container.decodeIfPresent([TimerRecord].self, forKey: .history) ?? []
        loopEnabled = try container.decodeIfPresent(Bool.self, forKey: .loopEnabled) ?? false
        presets = try container.decodeIfPresent([TimerPreset].self, forKey: .presets) ?? []
        activeTimer = try container.decodeIfPresent(TimerSpec.self, forKey: .activeTimer)
        remainingSeconds = try container.decodeIfPresent(Int.self, forKey: .remainingSeconds) ?? 0
        isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        activeStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeStartedAt)
    }
}

enum TimerInput {
    static func parse(_ input: String) -> TimerSpec? {
        let pieces = input.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let timeText = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = durationSeconds(timeText), seconds > 0, seconds <= 86_400 else { return nil }

        let tag = pieces.count == 2
            ? pieces[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            : ""
        return TimerSpec(seconds: seconds, tag: tag.isEmpty ? nil : tag)
    }

    private static func durationSeconds(_ input: String) -> Int? {
        if input.contains(":" ) {
            let parts = input.split(separator: ":", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard (2...3).contains(parts.count), let values = Optional(parts.compactMap(Int.init)), values.count == parts.count,
                  values.allSatisfy({ $0 >= 0 }) else { return nil }

            if values.count == 2 {
                guard values[1] < 60 else { return nil }
                return totalSeconds([(values[0], 60), (values[1], 1)])
            }
            guard values[1] < 60, values[2] < 60 else { return nil }
            return totalSeconds([(values[0], 3600), (values[1], 60), (values[2], 1)])
        }

        if let seconds = Int(input), seconds >= 0 { return seconds }

        let pattern = #"^\s*(?:(\d+)\s*(?:h|hr|hrs|hour|hours))?\s*(?:(\d+)\s*(?:m|min|mins|minute|minutes))?\s*(?:(\d+)\s*(?:s|sec|secs|second|seconds))?\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else { return nil }

        var components: [(Int, Int)] = []
        for (group, multiplier) in [(1, 3600), (2, 60), (3, 1)] {
            let range = match.range(at: group)
            guard range.location != NSNotFound else { continue }
            guard let swiftRange = Range(range, in: input), let value = Int(input[swiftRange]) else { return nil }
            components.append((value, multiplier))
        }
        guard !components.isEmpty else { return nil }
        return totalSeconds(components)
    }

    private static func totalSeconds(_ components: [(Int, Int)]) -> Int? {
        var total = 0
        for (value, multiplier) in components {
            let (component, multiplicationOverflow) = value.multipliedReportingOverflow(by: multiplier)
            let (sum, additionOverflow) = total.addingReportingOverflow(component)
            guard !multiplicationOverflow, !additionOverflow else { return nil }
            total = sum
        }
        return total
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