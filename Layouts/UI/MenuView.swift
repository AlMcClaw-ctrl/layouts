import KeyboardShortcuts
import SwiftUI

struct MenuView: View {
    @Environment(PresetStore.self) private var store
    @Environment(LayoutEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !AXPermission.isTrusted {
            Button("⚠️ Bedienungshilfen erlauben…") { AXPermission.request() }
            Divider()
        }

        if store.presets.isEmpty {
            Text("Noch keine Presets")
        }
        ForEach(store.presets) { preset in
            Button(preset.name) { Task { await engine.apply(preset) } }
                .globalKeyboardShortcut(Hotkeys.name(for: preset))
        }

        Divider()
        Button("Aktuelles Layout speichern…") {
            NSApp.activate()
            openWindow(id: "capture")
        }
        SettingsLink { Text("Einstellungen…") }
            .keyboardShortcut(",")

        if !engine.status.isEmpty {
            Divider()
            Text(engine.status)
        }
        if let error = store.lastError {
            Text(error)
        }

        Divider()
        Button("Beenden") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
