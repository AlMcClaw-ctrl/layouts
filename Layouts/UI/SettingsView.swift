import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("settingsFloating") private var floating = true

    var body: some View {
        TabView {
            PresetsTab()
                .tabItem { Label("Presets", systemImage: "rectangle.split.2x1") }
            GeneralTab()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
        }
        .frame(minWidth: 980, idealWidth: 1080, minHeight: 720, idealHeight: 820)
        .background(WindowLevel(floating: floating))
    }
}

private struct PresetsTab: View {
    @Environment(PresetStore.self) private var store
    @State private var selected: Preset.ID?

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selected) {
                    ForEach(store.presets) { preset in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name.isEmpty ? "Ohne Namen" : preset.name)
                            Text(preset.slots.map { $0.appName ?? $0.bundleID }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(preset.id)
                    }
                    .onMove { store.presets.move(fromOffsets: $0, toOffset: $1) }
                }
                HStack(spacing: 0) {
                    Button { add() } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                    Button { remove() } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                        .disabled(selected == nil)
                    Button { duplicate() } label: { Image(systemName: "plus.square.on.square").frame(width: 24, height: 20) }
                        .disabled(selected == nil)
                        .help("Duplizieren")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 230)

            Divider()

            if let i = store.presets.firstIndex(where: { $0.id == selected }) {
                PresetEditor(preset: $store.presets[i])
                    .id(store.presets[i].id)
            } else {
                Text("Preset links auswählen")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if selected == nil { selected = store.presets.first?.id } }
    }

    private func add() {
        let p = Preset(name: "Neues Layout", slots: [])
        store.presets.append(p)
        selected = p.id
    }

    private func remove() {
        guard let i = store.presets.firstIndex(where: { $0.id == selected }) else { return }
        store.presets.remove(at: i)
        selected = store.presets.indices.contains(i) ? store.presets[i].id : store.presets.last?.id
    }

    private func duplicate() {
        guard let p = store.presets.first(where: { $0.id == selected }) else { return }
        var copy = Preset(name: p.name + " Kopie", others: p.others, slots: p.slots)
        copy.slots = copy.slots.map { var s = $0; s.id = UUID(); return s }
        store.presets.append(copy)
        selected = copy.id
    }
}

private struct GeneralTab: View {
    @Environment(PresetStore.self) private var store
    @AppStorage("settingsFloating") private var floating = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Einstellungsfenster immer im Vordergrund", isOn: $floating)
                Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                LabeledContent("Bedienungshilfen") {
                    if AXPermission.isTrusted {
                        Text("erlaubt ✓")
                    } else {
                        Button("Erlauben…") { AXPermission.request() }
                    }
                }
            }
            Section("Datei") {
                HStack {
                    Button("presets.json bearbeiten") { NSWorkspace.shared.open(store.url) }
                    Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([store.url]) }
                    Button("Neu laden") { store.load() }
                }
                if let error = store.lastError {
                    Text(error).foregroundStyle(.red)
                }
            }
            Section("Automatisieren") {
                LabeledContent("Preset anwenden", value: "layouts://apply?name=Coding")
                LabeledContent("Layout speichern", value: "layouts://capture?name=Neu")
            }
            .textSelection(.enabled)
        }
        .formStyle(.grouped)
    }
}
