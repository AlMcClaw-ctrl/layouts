import Foundation
import KeyboardShortcuts

/// Global hotkeys per preset. The first nine get ⌃⌥1…9 once as a default.
@MainActor
enum Hotkeys {
    private static let keys: [KeyboardShortcuts.Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]

    static func name(for preset: Preset) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name("preset-\(preset.id.uuidString)")
    }

    static func register(store: PresetStore, engine: LayoutEngine) {
        KeyboardShortcuts.removeAllHandlers()
        let defaults = UserDefaults.standard
        let usedNow = Set(store.presets.compactMap { KeyboardShortcuts.getShortcut(for: name(for: $0)) })

        for (i, preset) in store.presets.enumerated() {
            let n = name(for: preset)
            let flag = "defaultHotkeyAssigned-\(preset.id.uuidString)"
            if i < keys.count, !defaults.bool(forKey: flag) {
                let shortcut = KeyboardShortcuts.Shortcut(keys[i], modifiers: [.control, .option])
                if KeyboardShortcuts.getShortcut(for: n) == nil, !usedNow.contains(shortcut) {
                    KeyboardShortcuts.setShortcut(shortcut, for: n)
                }
                defaults.set(true, forKey: flag)
            }
            let id = preset.id
            KeyboardShortcuts.onKeyUp(for: n) {
                Task { @MainActor in
                    if let p = store.presets.first(where: { $0.id == id }) { await engine.apply(p) }
                }
            }
        }
    }
}
