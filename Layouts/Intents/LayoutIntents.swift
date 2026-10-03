import AppIntents

/// A preset as Shortcuts/Spotlight see it.
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
    static let title: LocalizedStringResource = "Apply Layout"
    static let description = IntentDescription("Arranges your windows according to a saved layout.")
    static let openAppWhenRun = false

    @Parameter(title: "Layout")
    var layout: PresetEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Apply \(\.$layout)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let core = LayoutsCore.shared
        guard let preset = core.store.presets.first(where: { $0.id == layout.id }) else {
            return .result(dialog: "The layout “\(layout.name)” no longer exists.")
        }
        await core.engine.apply(preset)
        return .result(dialog: "\(core.engine.status)")
    }
}

struct SaveLayoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Current Layout"
    static let description = IntentDescription("Saves all visible windows as a layout. A layout with the same name is replaced.")
    static let openAppWhenRun = false

    @Parameter(title: "Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Save current layout as \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let core = LayoutsCore.shared
        core.store.upsert(core.engine.capture(name: name, windows: core.engine.capturableWindows()))
        return .result(dialog: "Saved “\(name)”")
    }
}

struct LayoutsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApplyLayoutIntent(),
            phrases: [
                "Apply \(\.$layout) with \(.applicationName)",
                "\(.applicationName) \(\.$layout)",
                "Apply \(\.$layout) in \(.applicationName)",
            ],
            shortTitle: "Apply Layout",
            systemImageName: "rectangle.split.2x1"
        )
        AppShortcut(
            intent: SaveLayoutIntent(),
            phrases: ["Save layout in \(.applicationName)"],
            shortTitle: "Save Layout",
            systemImageName: "camera.viewfinder"
        )
    }
}
