import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: TimerStore
    @State private var showingAddRecord = false

    private var tagTotals: [(tag: String, seconds: Int)] {
        let totals = store.history.reduce(into: [String: Int]()) { result, record in
            guard let tag = record.tag else { return }
            result[tag, default: 0] += record.seconds
        }
        return totals.map { (tag: $0.key, seconds: $0.value) }
            .sorted { $0.seconds == $1.seconds ? $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending : $0.seconds > $1.seconds }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Label("TAGS", systemImage: "number")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 12)
                if tagTotals.isEmpty {
                    Text("Tags appear as you track sessions.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 18)
                } else {
                    List(tagTotals, id: \.tag) { item in
                        HStack {
                            Text("#\(item.tag)").lineLimit(1)
                            Spacer(minLength: 8)
                            Text(durationText(item.seconds))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.sidebar)
                }
                Spacer()
            }
            .frame(width: 205)
            .background(.regularMaterial)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        Text("\(store.history.count) timer sessions")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showingAddRecord = true } label: {
                        Label("Add entry", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)

                Divider()

                if store.history.isEmpty {
                    ContentUnavailableView("No timer history", systemImage: "chart.xyaxis.line", description: Text("Completed timers and manually added entries will appear here."))
                } else {
                    List {
                        ForEach(store.history) { record in
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.tag.map { "#\($0)" } ?? "Untitled session")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(durationText(record.seconds))
                                    .font(.system(size: 12, design: .monospaced))
                                Button(role: .destructive) { store.deleteRecord(record) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Delete entry")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .sheet(isPresented: $showingAddRecord) {
            AddHistoryRecordView { seconds, tag, date in
                store.addManualRecord(seconds: seconds, tag: tag, date: date)
            }
        }
    }
}

private struct AddHistoryRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var duration = "25:00"
    @State private var tag = ""
    @State private var date = Date()
    let onSave: (Int, String?, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Add history entry")
                .font(.system(size: 18, weight: .medium, design: .rounded))
            TextField("Duration (25:00)", text: $duration)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 4) {
                Text("#").foregroundStyle(.secondary)
                TextField("Tag (optional)", text: $tag)
                    .textFieldStyle(.roundedBorder)
            }
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(TimerInput.parse(duration) == nil)
            }
        }
        .padding(22)
        .frame(width: 330)
    }

    private func save() {
        guard let timer = TimerInput.parse(duration) else { return }
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        onSave(timer.seconds, normalizedTag.isEmpty ? timer.tag : normalizedTag, date)
        dismiss()
    }
}