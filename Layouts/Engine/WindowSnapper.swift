import AppKit
import KeyboardShortcuts

/// Snap the focused window with a hotkey (halves, thirds, maximize, …), Rectangle-style.
enum SnapAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center, restore, nextDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: "Left half"
        case .rightHalf: "Right half"
        case .topHalf: "Top half"
        case .bottomHalf: "Bottom half"
        case .leftThird: "Left third"
        case .centerThird: "Center third"
        case .rightThird: "Right third"
        case .leftTwoThirds: "Left two thirds"
        case .rightTwoThirds: "Right two thirds"
        case .maximize: "Maximize"
        case .center: "Center"
        case .restore: "Restore"
        case .nextDisplay: "Next display"
        }
    }

    var symbol: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .leftThird, .centerThird, .rightThird: "rectangle.split.3x1"
        case .leftTwoThirds: "rectangle.leadinghalf.inset.filled"
        case .rightTwoThirds: "rectangle.trailinghalf.inset.filled"
        case .maximize: "rectangle.fill"
        case .center: "rectangle.center.inset.filled"
        case .restore: "arrow.uturn.backward"
        case .nextDisplay: "display.2"
        }
    }

    private var defaultShortcut: KeyboardShortcuts.Shortcut {
        let co: NSEvent.ModifierFlags = [.control, .option]
        switch self {
        case .leftHalf: return .init(.leftArrow, modifiers: co)
        case .rightHalf: return .init(.rightArrow, modifiers: co)
        case .topHalf: return .init(.upArrow, modifiers: co)
        case .bottomHalf: return .init(.downArrow, modifiers: co)
        case .leftThird: return .init(.d, modifiers: co)
        case .centerThird: return .init(.f, modifiers: co)
        case .rightThird: return .init(.g, modifiers: co)
        case .leftTwoThirds: return .init(.e, modifiers: co)
        case .rightTwoThirds: return .init(.t, modifiers: co)
        case .maximize: return .init(.return, modifiers: co)
        case .center: return .init(.c, modifiers: co)
        case .restore: return .init(.delete, modifiers: co)
        case .nextDisplay: return .init(.rightArrow, modifiers: [.control, .option, .command])
        }
    }

    var name: KeyboardShortcuts.Name { KeyboardShortcuts.Name("snap-\(rawValue)", default: defaultShortcut) }
}

@MainActor
enum WindowSnapper {
    static let enabledKey = "snapEnabled"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    /// Frames from before the first snap, for "Restore".
    private static var originals: [(AXUIElement, CGRect)] = []
    /// Last active app other than Layouts – a layouts:// URL briefly activates Layouts itself.
    private static var lastExternalApp: NSRunningApplication?
    private static var observing = false

    private static func trackFrontmostApp() {
        guard !observing else { return }
        observing = true
        lastExternalApp = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == getpid() ? nil : $0 }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                if let app, app.processIdentifier != getpid() { lastExternalApp = app }
            }
        }
    }

    private static func fail(_ reason: String) {
        LayoutsCore.shared.engine.status = "Snap: \(reason)"
        NSSound.beep()
    }

    static func registerHandlers() {
        trackFrontmostApp()
        guard isEnabled else { return }
        for action in SnapAction.allCases {
            KeyboardShortcuts.onKeyDown(for: action.name) {
                Task { @MainActor in perform(action) }
            }
        }
    }

    static func perform(_ action: SnapAction) {
        guard AXPermission.isTrusted else { AXPermission.request(); return }
        let front = NSWorkspace.shared.frontmostApplication
        guard let app = front?.processIdentifier == getpid() ? lastExternalApp : front else { return fail("no active app") }
        guard let window = AX.element(AX.app(app.processIdentifier), "AXFocusedWindow")
                ?? WindowInspector.windows(of: app).first(where: { !$0.isMinimized })?.element
        else { return fail("\(app.localizedName ?? "app") has no window") }
        guard AX.bool(window, "AXFullScreen") != true else { return fail("window is in full screen") }
        guard let frame = AX.frame(window), let screen = Screens.screen(for: frame) else { return fail("window frame unknown") }

        if action == .restore {
            guard let i = originals.firstIndex(where: { CFEqual($0.0, window) }) else { return fail("nothing to restore") }
            AX.setFrame(window, originals[i].1)
            originals.remove(at: i)
            return
        }

        if !originals.contains(where: { CFEqual($0.0, window) }) {
            originals.append((window, frame))
            if originals.count > 50 { originals.removeFirst() }
        }

        let current = Screens.relative(frame, on: screen)
        var target = screen
        let unit: UnitRect

        switch action {
        case .leftHalf: unit = cycle(current, widths: [1.0 / 2, 2.0 / 3, 1.0 / 3]) { UnitRect(x: 0, y: 0, w: $0, h: 1) }
        case .rightHalf: unit = cycle(current, widths: [1.0 / 2, 2.0 / 3, 1.0 / 3]) { UnitRect(x: 1 - $0, y: 0, w: $0, h: 1) }
        case .topHalf: unit = UnitRect(x: 0, y: 0, w: 1, h: 0.5)
        case .bottomHalf: unit = UnitRect(x: 0, y: 0.5, w: 1, h: 0.5)
        case .leftThird: unit = UnitRect(x: 0, y: 0, w: 1 / 3, h: 1)
        case .centerThird: unit = UnitRect(x: 1 / 3, y: 0, w: 1 / 3, h: 1)
        case .rightThird: unit = UnitRect(x: 2 / 3, y: 0, w: 1 / 3, h: 1)
        case .leftTwoThirds: unit = UnitRect(x: 0, y: 0, w: 2 / 3, h: 1)
        case .rightTwoThirds: unit = UnitRect(x: 1 / 3, y: 0, w: 2 / 3, h: 1)
        case .maximize: unit = .full
        case .center:
            let w = min(current.w, 1), h = min(current.h, 1)
            unit = UnitRect(x: (1 - w) / 2, y: (1 - h) / 2, w: w, h: h)
        case .nextDisplay:
            let screens = NSScreen.screens
            guard screens.count > 1, let i = screens.firstIndex(of: screen) else { return fail("only one display") }
            target = screens[(i + 1) % screens.count]
            unit = current
        case .restore:
            return
        }

        AX.setFrame(window, Screens.absolute(unit, on: target))
    }

    /// Pressing the same key again steps through the widths (½ → ⅔ → ⅓ → ½ …).
    private static func cycle(_ current: UnitRect, widths: [Double], _ make: (Double) -> UnitRect) -> UnitRect {
        let rects = widths.map(make)
        guard let i = rects.firstIndex(where: { close($0, current) }) else { return rects[0] }
        return rects[(i + 1) % rects.count]
    }

    private static func close(_ a: UnitRect, _ b: UnitRect) -> Bool {
        abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01 && abs(a.w - b.w) < 0.01 && abs(a.h - b.h) < 0.01
    }
}
