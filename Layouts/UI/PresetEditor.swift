import KeyboardShortcuts
import SwiftUI

/// Rechte Seite der Einstellungen: ein Preset mit Bildschirm-Vorschau bearbeiten.
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
                Picker("Bildschirm", selection: $screenRef) {
                    ForEach(NSScreen.screens, id: \.self) { s in
                        Text(s == Screens.primary ? "Hauptbildschirm" : s.localizedName).tag(Screens.ref(for: s))
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
                    Label("Fenster hinzufügen", systemImage: "plus")
                }
                .fixedSize()

                Button {
                    takeOverCurrentWindows()
                } label: {
                    Label("Aktuelle Fensterpositionen übernehmen", systemImage: "camera.viewfinder")
                }
                .help("Ersetzt die Plätze durch alle gerade sichtbaren Fenster. Tipp: erst anwenden, von Hand zurechtrücken, dann übernehmen.")

                Spacer()
                Text(useGrid ? "Ziehen · Ecke skaliert" : "Ziehen · Ecke skaliert · ⌥ = ohne Magnet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Raster", isOn: $useGrid)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Kacheln auf ¹⁄₂₄ einrasten (Halbe, Drittel, Viertel …)")
            }

            if let i = preset.slots.firstIndex(where: { $0.id == selection }) {
                SlotInspector(slot: $preset.slots[i],
                              others: preset.slots.filter { $0.id != selection && $0.screen == preset.slots[i].screen }) {
                    selection = nil
                    preset.slots.remove(at: i)
                }
                .id(preset.slots[i].id)
            } else {
                Text(preset.slots.isEmpty ? "Noch keine Fenster – oben „Fenster hinzufügen“."
                                          : "Kachel anklicken, um App, Position und Verhalten einzustellen.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding()
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
                Label("Anwenden", systemImage: "play.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
    }

    /// Automatisch anwenden, wenn genau diese Bildschirme verbunden werden.
    private var autoMenu: some View {
        let current = Screens.signature
        let isCurrent = preset.autoScreens == current
        return Menu {
            Button {
                preset.autoScreens = isCurrent ? nil : current
            } label: {
                if isCurrent {
                    Label("Bei „\(Screens.describe(current))“ automatisch", systemImage: "checkmark")
                } else {
                    Text("Automatisch bei „\(Screens.describe(current))“")
                }
            }
            if let auto = preset.autoScreens, auto != current {
                Button("Automatik für „\(Screens.describe(auto))“ entfernen") { preset.autoScreens = nil }
            }
        } label: {
            Label(preset.autoScreens == nil ? "Manuell" : "Automatisch",
                  systemImage: preset.autoScreens == nil ? "display" : "display.and.arrow.down")
        }
        .fixedSize()
        .help("Preset automatisch anwenden, sobald diese Bildschirm-Kombination angeschlossen wird")
    }

    private func addSlot(_ app: AppCatalog.Entry) {
        // Neue Kachel in die rechte Hälfte, wenn die linke schon belegt ist
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
            // Einstellungen zum Neu-Öffnen vom bisherigen Platz derselben App übernehmen
            if let old = preset.slots.first(where: { $0.bundleID == s.bundleID && $0.match.index == s.match.index }) {
                s.launch = old.launch
                s.match.title = old.match.title ?? s.match.title
            }
            return s
        }
        selection = nil
    }
}
