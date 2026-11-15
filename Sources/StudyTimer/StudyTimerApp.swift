import SwiftUI

@main
struct StudyTimerApp: App {
    @NSApplicationDelegateAdaptor(StudyTimerAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}