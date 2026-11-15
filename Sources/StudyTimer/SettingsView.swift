import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TimerStore
    @State private var recording: ShortcutKind?
    @State private var startsAtLogin = false
    @State private var loginItemError: String?

    private let sounds = ["Glass", "Ping", "Pop", "Purr", "Submarine", "Tink", "Funk", "Hero"]

    var body: some View {
        Form {
            Section {
                Link(destination: URL(string: "https://ko-fi.com/danielromanovski")!) {
                    Label("Donate", systemImage: "heart")
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Shortcuts") {
                shortcutRow("New timer", kind: .create, shortcut: store.preferences.createShortcut)
                shortcutRow("Start / pause", kind: .toggle, shortcut: store.preferences.toggleShortcut)
                Text("Global shortcuts may require Accessibility permission in System Settings.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section("Timer complete") {
                Picker("Sound", selection: binding(\.soundName)) {
                    ForEach(sounds, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Text("Volume")
                    Slider(value: binding(\.volume), in: 0...1)
                    Text("\(Int(store.preferences.volume * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 34, alignment: .trailing)
                }
                .onTapGesture(count: 2) { previewSound() }
            }

            Section("Behavior") {
                Toggle("macOS notification when a timer ends", isOn: notificationBinding)
                Toggle("Prevent system sleep while running", isOn: binding(\.preventSleep))
                Toggle("Start StudyTimer at login", isOn: $startsAtLogin)
                Text("The display can still turn off; only idle system sleep is prevented.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Quit StudyTimer", role: .destructive) { store.quit() }
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(minWidth: 440, minHeight: 440)
        .onAppear { startsAtLogin = SMAppService.mainApp.status == .enabled }
        .onChange(of: startsAtLogin) { _, enabled in updateLoginItem(enabled) }
        .alert("Unable to update login item", isPresented: Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) { loginItemError = nil }
        } message: {
            Text(loginItemError ?? "StudyTimer could not update its login setting.")
        }
    }

    @ViewBuilder
    private func shortcutRow(_ title: String, kind: ShortcutKind, shortcut: TimerShortcut) -> some View {
        HStack {
            Text(title)
            Spacer()
            ShortcutCaptureButton(shortcut: shortcut, isRecording: recording == kind) { captured in
                updateShortcut(captured, kind: kind)
                recording = nil
            }
            .frame(width: 130, height: 28)
        }
        .onChange(of: recording) { _, value in
            if value != kind { return }
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(get: { store.preferences.notificationsEnabled }, set: { enabled in
            store.preferences.notificationsEnabled = enabled
            if enabled { store.requestNotificationPermission() }
        })
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<TimerPreferences, Value>) -> Binding<Value> {
        Binding(get: { store.preferences[keyPath: keyPath] }, set: { store.preferences[keyPath: keyPath] = $0 })
    }

    private func updateShortcut(_ shortcut: TimerShortcut, kind: ShortcutKind) {
        if kind == .create { store.preferences.createShortcut = shortcut }
        else { store.preferences.toggleShortcut = shortcut }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
            startsAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func previewSound() {
        guard let sound = NSSound(named: NSSound.Name(store.preferences.soundName)) else { return }
        sound.volume = Float(store.preferences.volume)
        sound.play()
    }
}

private enum ShortcutKind: Equatable { case create, toggle }

private struct ShortcutCaptureButton: NSViewRepresentable {
    var shortcut: TimerShortcut
    var isRecording: Bool
    var onCapture: (TimerShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ view: ShortcutCaptureNSView, context: Context) {
        view.shortcut = shortcut
        view.isRecording = isRecording
        view.onCapture = onCapture
        view.needsDisplay = true
    }
}

private final class ShortcutCaptureNSView: NSView {
    var shortcut = TimerShortcut.createDefault
    var isRecording = false
    var onCapture: ((TimerShortcut) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !flags.isEmpty else { NSSound.beep(); return }
        let captured = TimerShortcut(keyCode: event.keyCode, modifiers: flags.rawValue)
        isRecording = false
        onCapture?(captured)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.13) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()
        let title = isRecording ? "Press shortcut…" : shortcut.title
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        text.draw(at: NSPoint(x: (bounds.width - text.size().width) / 2, y: (bounds.height - text.size().height) / 2))
    }
}