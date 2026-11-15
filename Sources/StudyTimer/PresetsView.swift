import SwiftUI

struct PresetsView: View {
    @EnvironmentObject private var store: TimerStore
    @State private var editingPreset: TimerPreset?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Presets")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                    Text("Saved timer sequences")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editingPreset = TimerPreset(
                        name: "",
                        timers: [TimerSpec(seconds: 25 * 60, tag: nil)],
                        loopEnabled: false
                    )
                } label: {
                    Label("New preset", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider()

            if store.presets.isEmpty {
                ContentUnavailableView("No presets yet", systemImage: "square.stack.3d.up", description: Text("Create a named timer or a multi-step loop."))
            } else {
                List {
                    ForEach(store.presets) { preset in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(preset.name)
                                    .font(.system(size: 13, weight: .medium))
                                HStack(spacing: 6) {
                                    Text(preset.timers.map { durationText($0.seconds) }.joined(separator: "  →  "))
                                    if preset.loopEnabled {
                                        Image(systemName: "repeat")
                                            .help("Repeats after the last timer")
                                    }
                                }
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Button { store.start(preset) } label: {
                                Image(systemName: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .help("Start preset")
                            Button { editingPreset = preset } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Edit preset")
                            Button(role: .destructive) { store.deletePreset(preset) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete preset")
                        }
                        .padding(.vertical, 5)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 500, minHeight: 360)
        .sheet(item: $editingPreset) { preset in
            PresetEditorView(preset: preset) { savedPreset in
                store.savePreset(savedPreset)
            }
        }
    }
}

private struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var timerInputs: [String]
    @State private var loopEnabled: Bool

    let preset: TimerPreset
    let onSave: (TimerPreset) -> Void

    init(preset: TimerPreset, onSave: @escaping (TimerPreset) -> Void) {
        self.preset = preset
        self.onSave = onSave
        _name = State(initialValue: preset.name)
        _timerInputs = State(initialValue: preset.timers.map { timer in
            timer.tag.map { "\(durationText(timer.seconds)) #\($0)" } ?? durationText(timer.seconds)
        })
        _loopEnabled = State(initialValue: preset.loopEnabled)
    }

    private var parsedTimers: [TimerSpec] { timerInputs.compactMap(TimerInput.parse) }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !timerInputs.isEmpty && parsedTimers.count == timerInputs.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(preset.name.isEmpty ? "New preset" : "Edit preset")
                .font(.system(size: 18, weight: .medium, design: .rounded))

            TextField("Preset name", text: $name)
                .textFieldStyle(.roundedBorder)

            Text("TIMERS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(timerInputs.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            TextField("35:00 #study", text: timerBinding(at: index))
                                .textFieldStyle(.roundedBorder)
                            Button(role: .destructive) {
                                timerInputs.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .disabled(timerInputs.count == 1)
                            .help("Remove timer")
                        }
                    }
                }
            }
            .frame(maxHeight: 190)

            Button {
                timerInputs.append("15:00")
            } label: {
                Label("Add timer", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Toggle("Loop this sequence", isOn: $loopEnabled)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 390, height: 440)
    }

    private func timerBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { timerInputs.indices.contains(index) ? timerInputs[index] : "" },
            set: { if timerInputs.indices.contains(index) { timerInputs[index] = $0 } }
        )
    }

    private func save() {
        guard canSave else { return }
        var savedPreset = preset
        savedPreset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        savedPreset.timers = parsedTimers
        savedPreset.loopEnabled = loopEnabled
        onSave(savedPreset)
        dismiss()
    }
}