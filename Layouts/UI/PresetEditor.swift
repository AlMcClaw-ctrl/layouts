import KeyboardShortcuts
import SwiftUI

/// Right side of the settings: edit one preset with a display preview.
struct PresetEditor: View {
    @Binding var preset: Preset
    @Environment(LayoutEngine.self) private var engine
    @State private var selection: Slot.ID?
    @State private var screenRef = "main"
    @AppStorage("editorGrid") private var useGrid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if NSScreen.screens.count > 1 {
                Picker("Display", selection: $screenRef) {
                    ForEach(NSScreen.screens, id: \.self) { s in
                        Text(s == Screens.primary ? "Main Display" : s.localizedName).tag(Screens.ref(for: s))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if let screen = Screens.resolve(screenRef) {
                LayoutCanvas(slots: $preset.slots, selection: $selection, screen: screen, useGrid: useGrid)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Menu {
                    ForEach(AppCatalog.runningApps()) { app in
                        Button(app.name) { addSlot(app) }
                    }
                } label: {
                    Label("Add Window", systemImage: "plus")
                }
                .fixedSize()

                Button {
                    takeOverCurrentWindows()
                } label: {
                    Label("Use Current Window Positions", systemImage: "camera.viewfinder")
                }
                .help("Replaces the slots with all currently visible windows. Tip: apply the preset, adjust windows by hand, then click this.")

                Spacer()
                Text(useGrid ? "Drag · corner resizes" : "Drag · corner resizes · ⌥ = no snapping")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Grid", isOn: $useGrid)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Snap tiles to a ¹⁄₂₄ grid (halves, thirds, quarters …)")
            }

            if let i = preset.slots.firstIndex(where: { $0.id == selection }) {
                SlotInspector(slot: $preset.slots[i],
                              others: preset.slots.filter { $0.id != selection && $0.screen == preset.slots[i].screen }) {
                    selection = nil
                    preset.slots.remove(at: i)
                }
                .id(preset.slots[i].id)
            } else {
                Text(preset.slots.isEmpty ? "No windows yet – use “Add Window” above."
                                          : "Click a tile to set its app, position and behavior.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField("Name", text: $preset.name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .frame(maxWidth: 240)
            KeyboardShortcuts.Recorder(for: Hotkeys.name(for: preset))
            Picker("", selection: $preset.others) {
                ForEach(Preset.Others.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            autoMenu
            Spacer()
            Button {
                Task { await engine.apply(preset) }
            } label: {
                Label("Apply", systemImage: "play.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
    }

    /// Apply automatically when exactly these displays are connected.
    private var autoMenu: some View {
        let current = Screens.signature
        let isCurrent = preset.autoScreens == current
        return Menu {
            Button {
                preset.autoScreens = isCurrent ? nil : current
            } label: {
                if isCurrent {
                    Label("Automatically on “\(Screens.describe(current))”", systemImage: "checkmark")
                } else {
                    Text("Apply automatically on “\(Screens.describe(current))”")
                }
            }
            if let auto = preset.autoScreens, auto != current {
                Button("Remove automation for “\(Screens.describe(auto))”") { preset.autoScreens = nil }
            }
        } label: {
            Label(preset.autoScreens == nil ? "Manual" : "Automatic",
                  systemImage: preset.autoScreens == nil ? "display" : "display.and.arrow.down")
        }
        .fixedSize()
        .help("Apply this preset automatically when this display combination is connected")
    }

    private func addSlot(_ app: AppCatalog.Entry) {
        // Put a new tile on the right half if the left one is taken
        let leftTaken = preset.slots.contains { $0.frame == .leftHalf }
        let slot = Slot(bundleID: app.bundleID, appName: app.name,
                        screen: screenRef, frame: leftTaken ? .rightHalf : .leftHalf)
        preset.slots.append(slot)
        selection = slot.id
    }

    private func takeOverCurrentWindows() {
        let captured = engine.capture(name: preset.name, windows: engine.capturableWindows()).slots
        preset.slots = captured.map { new in
            var s = new
            // Keep the launch settings from the previous slot of the same app
            if let old = preset.slots.first(where: { $0.bundleID == s.bundleID && $0.match.index == s.match.index }) {
                s.launch = old.launch
                s.match.title = old.match.title ?? s.match.title
            }
            return s
        }
        selection = nil
    }
}
