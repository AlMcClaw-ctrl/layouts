import AppKit

/// Gemeinsamer Zustand für Menü, Einstellungen, URL-Schema und Kurzbefehle.
@MainActor
final class LayoutsCore {
    static let shared = LayoutsCore()

    let store = PresetStore()
    let engine = LayoutEngine()

    private var lastScreens: [String] = []
    private var screenChange: Task<Void, Never>?

    private init() {}

    func start() {
        store.onChange = { [unowned self] in
            Hotkeys.register(store: store, engine: engine)
            LayoutsShortcuts.updateAppShortcutParameters()
        }
        Hotkeys.register(store: store, engine: engine)
        LayoutsShortcuts.updateAppShortcutParameters()

        lastScreens = Screens.signature
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in LayoutsCore.shared.screensChanged() }
        }
    }

    /// Bildschirm an-/abgesteckt → passendes Preset automatisch anwenden.
    /// Kurz warten: macOS meldet beim Umstecken mehrere Änderungen hintereinander.
    private func screensChanged() {
        screenChange?.cancel()
        screenChange = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            let now = Screens.signature
            guard now != lastScreens else { return }
            lastScreens = now
            if let preset = store.presets.first(where: { $0.autoScreens == now }) {
                await engine.apply(preset)
            }
        }
    }
}
