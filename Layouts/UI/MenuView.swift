import KeyboardShortcuts
import SwiftUI

struct MenuView: View {
    @Environment(PresetStore.self) private var store
    @Environment(LayoutEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !AXPermission.isTrusted {
            Button("⚠️ Grant Accessibility Access…") { AXPermission.request() }
            Divider()
        }

        if store.presets.isEmpty {
            Text("No presets yet")
        }
        ForEach(store.presets) { preset in
            Button(preset.name) { Task { await engine.apply(preset) } }
                .globalKeyboardShortcut(Hotkeys.name(for: preset))
        }

        Divider()
        Button("Save Current Layout…") {
            NSApp.activate()
            openWindow(id: "capture")
        }
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")

        if !engine.status.isEmpty {
            Divider()
            Text(engine.status)
        }
        if let error = store.lastError {
            Text(error)
        }

        Divider()
        Button("Quit Layouts") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
