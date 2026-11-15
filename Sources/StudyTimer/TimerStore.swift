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
    @Published var preferences: TimerPreferences { didSet { persist(); updateSleepAssertion() } }

    private let defaultsKey = "StudyTimer.state"
    private var tickTimer: Timer?
    private var activeStartedAt: Date?
    private var sleepAssertion: IOPMAssertionID = 0

    init() {
        let saved = UserDefaults.standard.data(forKey: "StudyTimer.state")
            .flatMap { try? JSONDecoder().decode(PersistedState.self, from: $0) } ?? PersistedState()
        _preferences = Published(initialValue: saved.preferences)
        _queue = Published(initialValue: saved.queue)
        _history = Published(initialValue: saved.history)
        _loopEnabled = Published(initialValue: saved.loopEnabled)
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
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        updateSleepAssertion()
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
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
        updateSleepAssertion()
    }

    func handleShortcut(keyCode: UInt16, modifiers: UInt) {
        if keyCode == preferences.createShortcut.keyCode && modifiers == preferences.createShortcut.modifiers {
            let last = history.first.map { TimerSpec(seconds: $0.seconds, tag: $0.tag) }
            start(last ?? TimerSpec(seconds: 25 * 60, tag: nil))
        } else if keyCode == preferences.toggleShortcut.keyCode && modifiers == preferences.toggleShortcut.modifiers {
            togglePause()
        }
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
        NSApplication.shared.terminate(nil)
    }

    private func tick() {
        guard isRunning else { return }
        if remainingSeconds > 1 {
            remainingSeconds -= 1
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
        }
    }

    private func playCompletionSound() {
        guard let sound = NSSound(named: NSSound.Name(preferences.soundName)) else { return }
        sound.volume = Float(preferences.volume)
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
        let state = PersistedState(preferences: preferences, queue: queue, history: history, loopEnabled: loopEnabled)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}