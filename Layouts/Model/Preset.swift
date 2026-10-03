import Foundation

/// Ein gespeichertes Layout: welche App-Fenster wo liegen sollen.
struct Preset: Codable, Identifiable, Hashable {
    /// Was mit Fenstern passiert, die nicht zum Preset gehören.
    enum Others: String, Codable, CaseIterable {
        case minimize, hide, keep

        var label: String {
            switch self {
            case .minimize: "Andere minimieren"
            case .hide: "Andere Apps ausblenden"
            case .keep: "Andere offen lassen"
            }
        }
    }

    var id = UUID()
    var name: String
    var others = Others.minimize
    /// Automatisch anwenden, sobald genau diese Bildschirme verbunden sind (sortierte Display-UUIDs).
    var autoScreens: [String]?
    var slots: [Slot] = []

    init(name: String, others: Others = .minimize, slots: [Slot]) {
        self.name = name
        self.others = others
        self.slots = slots
    }

    // Tolerant dekodieren, damit presets.json von Hand editierbar bleibt.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        others = try c.decodeIfPresent(Others.self, forKey: .others) ?? .minimize
        autoScreens = try c.decodeIfPresent([String].self, forKey: .autoScreens)
        slots = try c.decodeIfPresent([Slot].self, forKey: .slots) ?? []
    }
}

/// Ein Fensterplatz innerhalb eines Presets.
struct Slot: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleID: String
    var appName: String?
    /// Welches Fenster der App gemeint ist.
    var match = WindowMatch()
    /// "main" = Hauptbildschirm, sonst Display-UUID oder Bildschirmname.
    var screen = "main"
    /// Relativ (0…1) zum sichtbaren Bereich des Bildschirms, Ursprung oben links.
    var frame: UnitRect
    /// Wie ein fehlendes Fenster geöffnet wird.
    var launch: LaunchSpec?

    init(bundleID: String, appName: String? = nil, match: WindowMatch = WindowMatch(),
         screen: String = "main", frame: UnitRect, launch: LaunchSpec? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.match = match
        self.screen = screen
        self.frame = frame
        self.launch = launch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleID = try c.decode(String.self, forKey: .bundleID)
        appName = try c.decodeIfPresent(String.self, forKey: .appName)
        match = try c.decodeIfPresent(WindowMatch.self, forKey: .match) ?? WindowMatch()
        screen = try c.decodeIfPresent(String.self, forKey: .screen) ?? "main"
        frame = try c.decode(UnitRect.self, forKey: .frame)
        launch = try c.decodeIfPresent(LaunchSpec.self, forKey: .launch)
    }
}

/// Bevorzugtes Fenster. Ohne Treffer wird ein beliebiges freies Fenster der App genommen.
struct WindowMatch: Codable, Hashable {
    var title: String?
    var index: Int?
}

struct UnitRect: Codable, Hashable {
    var x: Double, y: Double, w: Double, h: Double

    static let leftHalf = UnitRect(x: 0, y: 0, w: 0.5, h: 1)
    static let rightHalf = UnitRect(x: 0.5, y: 0, w: 0.5, h: 1)
    static let full = UnitRect(x: 0, y: 0, w: 1, h: 1)

    var maxX: Double { x + w }

    /// Gleiche Oberkante/Höhe wie `ref`, füllt die größere freie Seite daneben.
    func fillingBeside(_ ref: UnitRect) -> UnitRect {
        let left = ref.x, right = 1 - ref.maxX
        return right >= left
            ? UnitRect(x: ref.maxX, y: ref.y, w: right, h: ref.h)
            : UnitRect(x: 0, y: ref.y, w: left, h: ref.h)
    }

    /// Gleiche Größe wie `ref`, direkt daneben (rechts, sonst links, notfalls am Rand).
    func sameSizeBeside(_ ref: UnitRect) -> UnitRect {
        let x = ref.maxX + ref.w <= 1.0001 ? ref.maxX
              : ref.x - ref.w >= -0.0001 ? ref.x - ref.w
              : (ref.x > 1 - ref.maxX ? 0 : 1 - ref.w)
        return UnitRect(x: max(0, x), y: ref.y, w: ref.w, h: ref.h)
    }

    /// Nur Oberkante und Höhe übernehmen.
    func sameRow(_ ref: UnitRect) -> UnitRect {
        UnitRect(x: x, y: ref.y, w: w, h: ref.h)
    }
}

struct LaunchSpec: Codable, Hashable {
    enum Kind: String, Codable { case newWindow, url, terminal }
    var kind: Kind
    var url: String?
    var cwd: String?
    var command: String?
}

extension Preset {
    static let claude = "com.anthropic.claudefordesktop"
    static let chrome = "com.google.Chrome"
    static let hermes = "com.nousresearch.hermes"

    static let examples: [Preset] = [
        Preset(name: "Coding", slots: [
            Slot(bundleID: chrome, appName: "Chrome", frame: .leftHalf),
            Slot(bundleID: claude, appName: "Claude", frame: .rightHalf),
        ]),
        Preset(name: "Doppel-Claude", slots: [
            Slot(bundleID: claude, appName: "Claude", match: WindowMatch(index: 0), frame: .leftHalf),
            Slot(bundleID: claude, appName: "Claude", match: WindowMatch(index: 1), frame: .rightHalf),
        ]),
        Preset(name: "Hermes + Claude", slots: [
            Slot(bundleID: hermes, appName: "Hermes", frame: .leftHalf),
            Slot(bundleID: claude, appName: "Claude", frame: .rightHalf),
        ]),
    ]
}
