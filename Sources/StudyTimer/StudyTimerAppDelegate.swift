import AppKit
import Combine
import SwiftUI

@MainActor
final class StudyTimerAppDelegate: NSObject, NSApplicationDelegate {
    let store = TimerStore()

    private let hotkeys = ShortcutMonitor()
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var statusSubscription: AnyCancellable?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var activityWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var presetsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createStatusItem()
        hotkeys.start(store: store)
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        item.button?.title = store.statusText
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.toolTip = "StudyTimer"
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemAction)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 310, height: 230)
        popover.contentViewController = NSHostingController(
            rootView: TimerPopoverView(
                onOpenActivity: { [weak self] in self?.showActivityWindow() },
                onOpenSettings: { [weak self] in self?.showSettingsWindow() },
                onOpenPresets: { [weak self] in self?.showPresetsWindow() }
            )
            .environmentObject(store)
        )
        statusPopover = popover
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissPopoverForOutsideClick()
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissPopoverForOutsideClick()
            }
        }

        statusSubscription = store.$remainingSeconds.sink { [weak self] seconds in
            self?.statusItem?.button?.title = durationText(seconds)
        }
    }

    @objc private func handleStatusItemAction() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusContextMenu()
            return
        }
        guard let button = statusItem?.button, let statusPopover else { return }
        if statusPopover.isShown {
            statusPopover.performClose(nil)
        } else {
            store.stopCompletionSound()
            statusPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showStatusContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit StudyTimer", action: #selector(quitStudyTimer), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.minY), in: button)
    }

    private func dismissPopoverForOutsideClick() {
        guard let statusPopover, statusPopover.isShown else { return }
        let location = NSEvent.mouseLocation
        if let button = statusItem?.button,
           let buttonWindow = button.window,
           buttonWindow.convertToScreen(button.convert(button.bounds, to: nil)).contains(location) {
            return
        }
        if statusPopover.contentViewController?.view.window?.frame.contains(location) == true {
            return
        }
        statusPopover.performClose(nil)
    }

    @objc private func quitStudyTimer() {
        store.quit()
    }

    private func showActivityWindow() {
        statusPopover?.performClose(nil)
        Task { @MainActor [weak self] in
            self?.presentActivityWindow()
        }
    }

    private func presentActivityWindow() {
        let window = activityWindow ?? makeWindow(
            title: "StudyTimer Activity",
            size: NSSize(width: 780, height: 560),
            content: ActivityView().environmentObject(store)
        )
        activityWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettingsWindow() {
        statusPopover?.performClose(nil)
        Task { @MainActor [weak self] in
            self?.presentSettingsWindow()
        }
    }

    private func presentSettingsWindow() {
        let window = settingsWindow ?? makeWindow(
            title: "StudyTimer Settings",
            size: NSSize(width: 520, height: 510),
            content: SettingsView().environmentObject(store)
        )
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPresetsWindow() {
        statusPopover?.performClose(nil)
        Task { @MainActor [weak self] in
            self?.presentPresetsWindow()
        }
    }

    private func presentPresetsWindow() {
        let window = presetsWindow ?? makeWindow(
            title: "StudyTimer Presets",
            size: NSSize(width: 580, height: 500),
            content: PresetsView().environmentObject(store)
        )
        presetsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow<Content: View>(title: String, size: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: content)
        return window
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.persistForTermination()
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
    }
}