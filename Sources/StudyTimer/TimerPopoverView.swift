import SwiftUI

struct TimerPopoverView: View {
    @EnvironmentObject private var store: TimerStore
    @Environment(\.openWindow) private var openWindow
    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isRunning ? "IN FOCUS" : "STUDY TIMER")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                    Text(store.statusText)
                        .font(.system(size: 30, weight: .light, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                }
                Spacer()
                if store.activeTimer != nil {
                    Button { store.togglePause() } label: {
                        Image(systemName: store.isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .help(store.isRunning ? "Pause timer" : "Resume timer")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                TextField("35:00  #working", text: $input)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { beginTimer() }
                Button(action: addNextTimer) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help("Add as next timer")
                Button(action: beginTimer) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 11))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .help("Start timer")
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))

            if !store.queue.isEmpty {
                HStack {
                    Text("UP NEXT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Loop", isOn: $store.loopEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .help("Loop queued timers")
                    Text("Loop")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, timer in
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text(durationText(timer.seconds))
                                .font(.system(size: 12, design: .monospaced))
                            if let tag = timer.tag { Text("#\(tag)").font(.system(size: 11)).foregroundStyle(.secondary) }
                            Spacer()
                            Button { store.removeQueuedTimer(timer) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                            .help("Remove timer")
                        }
                        .padding(.vertical, 5)
                        if index < store.queue.count - 1 { Divider() }
                    }
                }
            } else if store.activeTimer == nil {
                Text("Type a duration to begin")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Divider()
            HStack {
                Button { openWindow(id: "activity") } label: { Image(systemName: "chart.xyaxis.line") }
                    .help("Activity and timer history")
                Button { openWindow(id: "settings") } label: { Image(systemName: "gearshape") }
                    .help("Settings")
                Spacer()
                if !store.history.isEmpty {
                    Text("\(store.history.count) completed")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 310)
        .background(.ultraThinMaterial)
        .onAppear { fieldFocused = store.activeTimer == nil }
    }

    private func beginTimer() {
        guard store.addTimer(from: input, start: true) else { NSSound.beep(); return }
        input = ""
    }

    private func addNextTimer() {
        guard store.addTimer(from: input) else { NSSound.beep(); return }
        input = ""
    }
}