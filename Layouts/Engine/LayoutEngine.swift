import AppKit
import Observation

@MainActor
@Observable
final class LayoutEngine {
    var status = ""
    var isRunning = false

    // MARK: Apply

    func apply(_ preset: Preset) async {
        guard AXPermission.isTrusted else {
            AXPermission.request()
            status = "Please grant Accessibility access"
            return
        }
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        var problems: [String] = []

        // 1. Make sure all involved apps are running
        var apps: [String: NSRunningApplication] = [:]
        for id in preset.slots.map(\.bundleID).uniqued() {
            if let app = await AppLauncher.ensureRunning(id) {
                apps[id] = app
            } else {
                problems.append("\(id) not found")
            }
        }

        // 2. Assign windows: title matches first, then index/free windows, then new windows
        var used: [AXUIElement] = []
        var assigned: [UUID: WindowInfo] = [:]
        func take(_ slot: Slot, _ w: WindowInfo) { assigned[slot.id] = w; used.append(w.element) }
        func free(_ bundleID: String) -> [WindowInfo] {
            WindowInspector.windows(bundleID: bundleID).filter { !AX.contains(used, $0.element) && !$0.isFullScreen }
        }

        for slot in preset.slots {
            guard let title = slot.match.title, apps[slot.bundleID] != nil else { continue }
            if let w = free(slot.bundleID).first(where: { $0.title.localizedCaseInsensitiveContains(title) }) {
                take(slot, w)
            }
        }
        for slot in preset.slots where assigned[slot.id] == nil {
            guard apps[slot.bundleID] != nil else { continue }
            let all = WindowInspector.windows(bundleID: slot.bundleID)
            if let i = slot.match.index, slot.match.title == nil, all.indices.contains(i),
               !AX.contains(used, all[i].element), !all[i].isFullScreen {
                take(slot, all[i])
            } else if let w = free(slot.bundleID).sorted(by: { !$0.isMinimized && $1.isMinimized }).first {
                take(slot, w)
            }
        }
        for slot in preset.slots where assigned[slot.id] == nil {
            guard let app = apps[slot.bundleID] else { continue }
            if let el = await AppLauncher.openWindow(for: slot, app: app),
               let w = WindowInspector.windows(of: app).first(where: { CFEqual($0.element, el) }) {
                take(slot, w)
            } else {
                problems.append("no new window for \(slot.appName ?? slot.bundleID)")
            }
        }

        // 3. Position (Electron apps briefly report wrong sizes → repeat after a short pause)
        place(preset, assigned)
        try? await Task.sleep(for: .milliseconds(300))
        place(preset, assigned)

        // 4. Clear everything else away
        switch preset.others {
        case .keep:
            break
        case .minimize:
            let keep = assigned.values.map(\.element)
            for w in WindowInspector.allWindows()
            where !w.app.isHidden && !w.isMinimized && !w.isFullScreen && !AX.contains(keep, w.element) {
                AX.set(w.element, "AXMinimized", kCFBooleanTrue)
            }
        case .hide:
            let keep = Set(preset.slots.map(\.bundleID))
            for app in WindowInspector.regularApps() where !keep.contains(app.bundleIdentifier ?? "") {
                app.hide()
            }
        }

        // 5. Raise in slot order
        for slot in preset.slots {
            guard let w = assigned[slot.id] else { continue }
            if w.app.isHidden { w.app.unhide() }
            AX.set(AX.app(w.app.processIdentifier), "AXFrontmost", kCFBooleanTrue)
            AX.set(w.element, "AXMain", kCFBooleanTrue)
            AX.perform(w.element, "AXRaise")
        }

        status = problems.isEmpty ? "Applied “\(preset.name)”" : "“\(preset.name)”: " + problems.joined(separator: ", ")
    }

    private func place(_ preset: Preset, _ assigned: [UUID: WindowInfo]) {
        for slot in preset.slots {
            guard let el = assigned[slot.id]?.element, let screen = Screens.resolve(slot.screen) else { continue }
            if AX.bool(el, "AXMinimized") == true { AX.set(el, "AXMinimized", kCFBooleanFalse) }
            AX.setFrame(el, Screens.absolute(slot.frame, on: screen))
        }
    }

    // MARK: Capture

    /// Builds a preset from the given (currently visible) windows.
    func capture(name: String, windows: [WindowInfo]) -> Preset {
        var perApp: [String: Int] = [:]
        let slots = windows.map { w -> Slot in
            let screen = Screens.screen(for: w.frame) ?? Screens.primary!
            let index = perApp[w.bundleID, default: 0]
            perApp[w.bundleID] = index + 1
            // Only remember titles for Terminal – we set those ourselves, other apps change them constantly.
            let isTerminal = w.bundleID == "com.apple.Terminal"
            return Slot(bundleID: w.bundleID, appName: w.appName,
                        match: WindowMatch(title: isTerminal && !w.title.isEmpty ? w.title : nil, index: index),
                        screen: Screens.ref(for: screen),
                        frame: Screens.relative(w.frame, on: screen))
        }
        return Preset(name: name, slots: slots)
    }

    /// All windows suitable for a preset (visible, not minimized, not full screen).
    func capturableWindows() -> [WindowInfo] {
        WindowInspector.regularApps()
            .filter { !$0.isHidden }
            .flatMap(WindowInspector.windows(of:))
            .filter { !$0.isMinimized && !$0.isFullScreen }
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
