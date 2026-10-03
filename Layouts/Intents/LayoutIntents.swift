import AppIntents

/// Ein Preset, wie Kurzbefehle/Spotlight es sehen.
struct PresetEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static let defaultQuery = PresetQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ preset: Preset) {
        id = preset.id
        name = preset.name
    }
}

struct PresetQuery: EntityStringQuery {
    @MainActor
    private var all: [PresetEntity] { LayoutsCore.shared.store.presets.map(PresetEntity.init) }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PresetEntity] {
        all.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [PresetEntity] {
        all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PresetEntity] { all }
}

struct ApplyLayoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Layout anwenden"
    static let description = IntentDescription("Ordnet die Fenster nach einem gespeicherten Layout an.")
    static let openAppWhenRun = false

    @Parameter(title: "Layout")
    var layout: PresetEntity

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$layout) anwenden")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let core = LayoutsCore.shared
        guard let preset = core.store.presets.first(where: { $0.id == layout.id }) else {
            return .result(dialog: "Layout „\(layout.name)“ gibt es nicht mehr.")
        }
        await core.engine.apply(preset)
        return .result(dialog: "\(core.engine.status)")
    }
}

struct SaveLayoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Aktuelles Layout speichern"
    static let description = IntentDescription("Speichert alle sichtbaren Fenster als Layout. Gleichnamige Layouts werden überschrieben.")
    static let openAppWhenRun = false

    @Parameter(title: "Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Aktuelles Layout als \(\.$name) speichern")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let core = LayoutsCore.shared
        core.store.upsert(core.engine.capture(name: name, windows: core.engine.capturableWindows()))
        return .result(dialog: "„\(name)“ gespeichert")
    }
}

struct LayoutsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApplyLayoutIntent(),
            phrases: [
                "\(\.$layout) in \(.applicationName) anwenden",
                "\(.applicationName) \(\.$layout)",
                "Apply \(\.$layout) in \(.applicationName)",
            ],
            shortTitle: "Layout anwenden",
            systemImageName: "rectangle.split.2x1"
        )
        AppShortcut(
            intent: SaveLayoutIntent(),
            phrases: ["Layout in \(.applicationName) speichern", "Save layout in \(.applicationName)"],
            shortTitle: "Layout speichern",
            systemImageName: "camera.viewfinder"
        )
    }
}
