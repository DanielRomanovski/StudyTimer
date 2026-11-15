import AppKit
import IOKit.pwr_mgt
import UserNotifications

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var activeTimer: TimerSpec?
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var isRunning = false
    @Published var queue: [TimerSpec] { didSet { persist() } }
    @Published var history: [TimerRecord] { didSet { persist() } }
    @Published var loopEnabled: Bool { didSet { persist() } }
    @Published var presets: [TimerPreset] { didSet { persist() } }
    @Published var preferences: TimerPreferences { didSet { persist(); updateSleepAssertion() } }

    private let defaultsKey = "StudyTimer.state"
    private let stateURL: URL
    private var tickTimer: Timer?
    private var activeStartedAt: Date?
    private var sleepAssertion: IOPMAssertionID = 0
    private var completionSound: NSSound?

    init() {
        let supportDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/StudyTimer", isDirectory: true)
        stateURL = supportDirectory.appendingPathComponent("state.json")
        let fileData = try? Data(contentsOf: stateURL)
        let legacyData = UserDefaults.standard.data(forKey: defaultsKey)
        let savedData = fileData ?? legacyData
        let saved = savedData.flatMap { try? JSONDecoder().decode(PersistedState.self, from: $0) } ?? PersistedState()
        _preferences = Published(initialValue: saved.preferences)
        _activeTimer = Published(initialValue: saved.activeTimer)
        _remainingSeconds = Published(initialValue: saved.activeTimer == nil ? 0 : saved.remainingSeconds)
        _isRunning = Published(initialValue: saved.activeTimer != nil && saved.isRunning)
        _queue = Published(initialValue: saved.queue)
        _history = Published(initialValue: saved.history)
        _loopEnabled = Published(initialValue: saved.loopEnabled)
        _presets = Published(initialValue: saved.presets)
        activeStartedAt = saved.activeStartedAt
        if fileData == nil, let legacyData {
            try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            try? legacyData.write(to: stateURL, options: .atomic)
        }
        if isRunning {
            scheduleTicker()
            updateSleepAssertion()
        }
    }

    var statusText: String { durationText(remainingSeconds) }

    func addTimer(from input: String, start shouldStart: Bool = false) -> Bool {
        guard let timer = TimerInput.parse(input) else { return false }
        if shouldStart {
            start(timer)
        } else {
            queue.append(timer)
        }
        return true
    }

    func start(_ timer: TimerSpec) {
        tickTimer?.invalidate()
        activeTimer = timer
        remainingSeconds = timer.seconds
        activeStartedAt = Date()
        isRunning = true
        scheduleTicker()
        updateSleepAssertion()
        persist()
    }

    func togglePause() {
        guard activeTimer != nil else { return }
        if isRunning {
            tickTimer?.invalidate()
            tickTimer = nil
            isRunning = false
        } else {
            activeStartedAt = Date().addingTimeInterval(TimeInterval(-(activeTimer!.seconds - remainingSeconds)))
            isRunning = true
            scheduleTicker()
        }
        updateSleepAssertion()
        persist()
    }

    func resetTimer() {
        guard let activeTimer else { return }
        tickTimer?.invalidate()
        tickTimer = nil
        remainingSeconds = activeTimer.seconds
        activeStartedAt = nil
        isRunning = false
        updateSleepAssertion()
        persist()
    }

    func cancelTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
        activeTimer = nil
        remainingSeconds = 0
        activeStartedAt = nil
        isRunning = false
        queue = []
        loopEnabled = false
        updateSleepAssertion()
        persist()
    }

    func start(_ preset: TimerPreset) {
        guard let firstTimer = preset.timers.first else { return }
        queue = Array(preset.timers.dropFirst())
        loopEnabled = preset.loopEnabled
        start(firstTimer)
    }

    func savePreset(_ preset: TimerPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
    }

    func deletePreset(_ preset: TimerPreset) {
        presets.removeAll { $0.id == preset.id }
    }

    func handleShortcut(keyCode: UInt16, modifiers: UInt) {
        if keyCode == preferences.createShortcut.keyCode && modifiers == preferences.createShortcut.modifiers {
            let last = history.first.map { TimerSpec(seconds: $0.seconds, tag: $0.tag) }
            start(last ?? TimerSpec(seconds: 25 * 60, tag: nil))
        } else if keyCode == preferences.toggleShortcut.keyCode && modifiers == preferences.toggleShortcut.modifiers {
            stopCompletionSound()
            togglePause()
        }
    }

    func importCustomSound(from sourceURL: URL) throws {
        let soundsDirectory = stateURL.deletingLastPathComponent().appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension
        let destination = soundsDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        preferences.customSoundFilename = destination.lastPathComponent
        previewCompletionSound()
    }

    func previewCompletionSound() {
        playSound(repeating: false)
    }

    func stopCompletionSound() {
        completionSound?.stop()
        completionSound = nil
    }

    func removeQueuedTimer(_ timer: TimerSpec) {
        queue.removeAll { $0.id == timer.id }
    }

    func deleteRecord(_ record: TimerRecord) {
        history.removeAll { $0.id == record.id }
    }

    func addManualRecord(seconds: Int, tag: String?, date: Date) {
        history.insert(TimerRecord(seconds: seconds, tag: tag, startedAt: date, endedAt: date), at: 0)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func quit() {
        persist()
        NSApplication.shared.terminate(nil)
    }

    func persistForTermination() {
        persist()
    }

    private func tick() {
        guard isRunning else { return }
        if remainingSeconds > 1 {
            remainingSeconds -= 1
            persist()
        } else {
            remainingSeconds = 0
            finishCurrentTimer()
        }
    }

    private func finishCurrentTimer() {
        guard let completed = activeTimer else { return }
        tickTimer?.invalidate()
        tickTimer = nil
        let startedAt = activeStartedAt ?? Date().addingTimeInterval(-TimeInterval(completed.seconds))
        let ended = Date()
        history.insert(TimerRecord(seconds: completed.seconds, tag: completed.tag, startedAt: startedAt, endedAt: ended), at: 0)
        playCompletionSound()
        if preferences.notificationsEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Timer complete"
            content.body = completed.tag.map { "\($0) is done." } ?? "Your timer is done."
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }

        if !queue.isEmpty {
            if loopEnabled { queue.append(completed) }
            start(queue.removeFirst())
        } else if loopEnabled {
            start(completed)
        } else {
            activeTimer = nil
            remainingSeconds = 0
            isRunning = false
            activeStartedAt = nil
            updateSleepAssertion()
            persist()
        }
    }

    private func scheduleTicker() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func playCompletionSound() {
        playSound(repeating: preferences.loopCompletionSound)
    }

    private func playSound(repeating: Bool) {
        stopCompletionSound()
        let sound: NSSound?
        if let filename = preferences.customSoundFilename {
            let url = stateURL.deletingLastPathComponent()
                .appendingPathComponent("Sounds", isDirectory: true)
                .appendingPathComponent(filename)
            sound = NSSound(contentsOf: url, byReference: false)
        } else {
            sound = NSSound(named: NSSound.Name(preferences.soundName))
        }
        guard let sound else { return }
        sound.volume = Float(preferences.volume)
        sound.loops = repeating
        completionSound = sound
        sound.play()
    }

    private func updateSleepAssertion() {
        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
        guard preferences.preventSleep, isRunning else { return }
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "StudyTimer is running" as CFString,
            &sleepAssertion
        )
    }

    private func persist() {
        let state = PersistedState(
            preferences: preferences,
            queue: queue,
            history: history,
            loopEnabled: loopEnabled,
            presets: presets,
            activeTimer: activeTimer,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            activeStartedAt: activeStartedAt
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateURL, options: .atomic)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}