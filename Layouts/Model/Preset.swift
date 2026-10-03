import Foundation

/// A saved layout: which app windows go where.
struct Preset: Codable, Identifiable, Hashable {
    /// What happens to windows that are not part of the preset.
    enum Others: String, Codable, CaseIterable {
        case minimize, hide, keep

        var label: String {
            switch self {
            case .minimize: "Minimize others"
            case .hide: "Hide other apps"
            case .keep: "Leave others open"
            }
        }
    }

    var id = UUID()
    var name: String
    var others = Others.minimize
    /// Apply automatically when exactly these displays are connected (sorted display UUIDs).
    var autoScreens: [String]?
    var slots: [Slot] = []

    init(name: String, others: Others = .minimize, slots: [Slot]) {
        self.name = name
        self.others = others
        self.slots = slots
    }

    // Decode leniently so presets.json stays hand-editable.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        others = try c.decodeIfPresent(Others.self, forKey: .others) ?? .minimize
        autoScreens = try c.decodeIfPresent([String].self, forKey: .autoScreens)
        slots = try c.decodeIfPresent([Slot].self, forKey: .slots) ?? []
    }
}

/// One window slot within a preset.
struct Slot: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleID: String
    var appName: String?
    /// Which window of the app is meant.
    var match = WindowMatch()
    /// "main" = primary display, otherwise display UUID or display name.
    var screen = "main"
    /// Relative (0…1) to the display's visible area, origin top left.
    var frame: UnitRect
    /// How a missing window is opened.
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

/// Preferred window. Without a match, any free window of the app is used.
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

    /// Same top/height as `ref`, fills the larger free side next to it.
    func fillingBeside(_ ref: UnitRect) -> UnitRect {
        let left = ref.x, right = 1 - ref.maxX
        return right >= left
            ? UnitRect(x: ref.maxX, y: ref.y, w: right, h: ref.h)
            : UnitRect(x: 0, y: ref.y, w: left, h: ref.h)
    }

    /// Same size as `ref`, right next to it (right, else left, else at the edge).
    func sameSizeBeside(_ ref: UnitRect) -> UnitRect {
        let x = ref.maxX + ref.w <= 1.0001 ? ref.maxX
              : ref.x - ref.w >= -0.0001 ? ref.x - ref.w
              : (ref.x > 1 - ref.maxX ? 0 : 1 - ref.w)
        return UnitRect(x: max(0, x), y: ref.y, w: ref.w, h: ref.h)
    }

    /// Take only top and height.
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
        Preset(name: "Two Claudes", slots: [
            Slot(bundleID: claude, appName: "Claude", match: WindowMatch(index: 0), frame: .leftHalf),
            Slot(bundleID: claude, appName: "Claude", match: WindowMatch(index: 1), frame: .rightHalf),
        ]),
        Preset(name: "Hermes + Claude", slots: [
            Slot(bundleID: hermes, appName: "Hermes", frame: .leftHalf),
            Slot(bundleID: claude, appName: "Claude", frame: .rightHalf),
        ]),
    ]
}
