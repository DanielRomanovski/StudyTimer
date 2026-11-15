import AppKit

@MainActor
final class ShortcutMonitor: ObservableObject {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var store: TimerStore?

    func start(store: TimerStore) {
        self.store = store
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.dispatch(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.dispatch(event)
            return event
        }
    }

    private func dispatch(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control]).rawValue
        let keyCode = event.keyCode
        Task { @MainActor [weak self] in
            self?.store?.handleShortcut(keyCode: keyCode, modifiers: flags)
        }
    }
}