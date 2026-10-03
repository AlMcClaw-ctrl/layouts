import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("settingsFloating") private var floating = true

    var body: some View {
        TabView {
            PresetsTab()
                .tabItem { Label("Presets", systemImage: "rectangle.split.2x1") }
            SnapTab()
                .tabItem { Label("Snapping", systemImage: "rectangle.righthalf.inset.filled.arrow.right") }
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
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
                            Text(preset.name.isEmpty ? "Untitled" : preset.name)
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
                        .help("Duplicate")
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
                Text("Select a preset on the left")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if selected == nil { selected = store.presets.first?.id } }
    }

    private func add() {
        let p = Preset(name: "New Layout", slots: [])
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
        var copy = Preset(name: p.name + " Copy", others: p.others, slots: p.slots)
        copy.slots = copy.slots.map { var s = $0; s.id = UUID(); return s }
        store.presets.append(copy)
        selected = copy.id
    }
}

private struct SnapTab: View {
    @AppStorage(WindowSnapper.enabledKey) private var enabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Snap the focused window with keyboard shortcuts", isOn: $enabled)
                    .onChange(of: enabled) { _, _ in
                        let core = LayoutsCore.shared
                        Hotkeys.register(store: core.store, engine: core.engine)
                    }
            } footer: {
                Text("Press ⌃⌥← or ⌃⌥→ repeatedly to cycle through ½, ⅔ and ⅓ of the screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                ForEach(SnapAction.allCases) { action in
                    LabeledContent {
                        KeyboardShortcuts.Recorder(for: action.name)
                    } label: {
                        Label(action.title, systemImage: action.symbol)
                    }
                }
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
    }
}

private struct GeneralTab: View {
    @Environment(PresetStore.self) private var store
    @AppStorage("settingsFloating") private var floating = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Keep settings window on top", isOn: $floating)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                LabeledContent("Accessibility") {
                    if AXPermission.isTrusted {
                        Text("Granted ✓")
                    } else {
                        Button("Grant Access…") { AXPermission.request() }
                    }
                }
            }
            Section("File") {
                HStack {
                    Button("Edit presets.json") { NSWorkspace.shared.open(store.url) }
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.url]) }
                    Button("Reload") { store.load() }
                }
                if let error = store.lastError {
                    Text(error).foregroundStyle(.red)
                }
            }
            Section("Automation") {
                LabeledContent("Apply preset", value: "layouts://apply?name=Coding")
                LabeledContent("Save layout", value: "layouts://capture?name=New")
            }
            .textSelection(.enabled)
        }
        .formStyle(.grouped)
    }
}
