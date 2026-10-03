import Foundation
import Observation

/// Loads/saves presets as JSON in ~/Library/Application Support/Layouts/presets.json.
@MainActor
@Observable
final class PresetStore {
    private struct File: Codable { var version = 1; var presets: [Preset] }

    var presets: [Preset] = [] {
        didSet { if !isLoading { save() }; onChange?() }
    }
    var lastError: String?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var isLoading = false

    let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Layouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("presets.json")
    }()

    init() { load() }

    func load() {
        isLoading = true
        defer { isLoading = false }
        guard FileManager.default.fileExists(atPath: url.path) else {
            presets = Preset.examples
            save()
            return
        }
        do {
            presets = try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).presets
            lastError = nil
        } catch {
            lastError = "presets.json is invalid: \(error.localizedDescription)"
        }
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            try enc.encode(File(presets: presets)).write(to: url, options: .atomic)
        } catch {
            lastError = "Could not save: \(error.localizedDescription)"
        }
    }

    func preset(named name: String) -> Preset? {
        presets.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    /// Replace a preset with the same name (ID and hotkey are kept), otherwise append.
    func upsert(_ p: Preset) {
        if let i = presets.firstIndex(where: { $0.name == p.name }) {
            var updated = p
            updated.id = presets[i].id
            updated.others = presets[i].others
            presets[i] = updated
        } else {
            presets.append(p)
        }
    }
}
