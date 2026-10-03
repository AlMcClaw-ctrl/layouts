import SwiftUI

/// „Aktuelles Layout speichern“: Name vergeben, Fenster auswählen.
struct CaptureView: View {
    @Environment(PresetStore.self) private var store
    @Environment(LayoutEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    private struct Row: Identifiable {
        let id = UUID()
        let info: WindowInfo
        var selected = true
    }

    @State private var name = ""
    @State private var rows: [Row] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name, z. B. „Coding“", text: $name)
                .textFieldStyle(.roundedBorder)

            Text("Fenster, die ins Preset sollen:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List($rows) { $row in
                Toggle(isOn: $row.selected) {
                    VStack(alignment: .leading) {
                        Text(row.info.appName).bold()
                        Text(row.info.title.isEmpty ? "(ohne Titel)" : row.info.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(minHeight: 220)

            if store.preset(named: name) != nil {
                Text("Ein Preset mit diesem Namen wird überschrieben.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Neu einlesen", action: reload)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Speichern", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !rows.contains { $0.selected })
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear(perform: reload)
    }

    private func reload() {
        rows = engine.capturableWindows().map { Row(info: $0) }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        store.upsert(engine.capture(name: trimmed, windows: rows.filter(\.selected).map(\.info)))
        engine.status = "„\(trimmed)“ gespeichert"
        name = ""
        dismiss()
    }
}
