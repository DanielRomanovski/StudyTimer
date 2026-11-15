import SwiftUI

@main
struct StudyTimerApp: App {
    @StateObject private var store = TimerStore()
    @StateObject private var hotkeys = ShortcutMonitor()

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView()
                .environmentObject(store)
                .onAppear { hotkeys.start(store: store) }
        } label: {
            Text(store.statusText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .frame(minWidth: 42)
        }
        .menuBarExtraStyle(.window)

        Window("StudyTimer Activity", id: "activity") {
            ActivityView().environmentObject(store)
        }
        .defaultSize(width: 780, height: 560)

        Window("StudyTimer Settings", id: "settings") {
            SettingsView().environmentObject(store)
        }
        .defaultSize(width: 520, height: 510)
    }
}