import SwiftUI

@main
struct LayoutsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Layouts", systemImage: "rectangle.split.2x1") {
            MenuView()
                .environment(delegate.store)
                .environment(delegate.engine)
        }

        Window("Save Layout", id: "capture") {
            CaptureView()
                .environment(delegate.store)
                .environment(delegate.engine)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(delegate.store)
                .environment(delegate.engine)
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = LayoutsCore.shared.store
    let engine = LayoutsCore.shared.engine

    func applicationDidFinishLaunching(_ notification: Notification) {
        LayoutsCore.shared.start()
        if !AXPermission.isTrusted { AXPermission.request() }
    }

    /// layouts://apply?name=Coding · layouts://capture?name=New · layouts://settings · layouts://dump
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { Task { await handle(url) } }
    }

    private func handle(_ url: URL) async {
        let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "name" }?.value
        switch url.host {
        case "apply":
            if let name, let p = store.preset(named: name) {
                await engine.apply(p)
            } else {
                engine.status = "Preset “\(name ?? "")” not found"
            }
        case "capture":
            guard let name, !name.isEmpty else { return }
            store.upsert(engine.capture(name: name, windows: engine.capturableWindows()))
            engine.status = "Saved “\(name)”"
        case "settings":
            NSApp.activate()
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case "dump":
            dumpWindows()
        default:
            break
        }
        writeStatus()
    }

    /// Debug: current windows + status as JSON next to presets.json.
    private func dumpWindows() {
        let rows = WindowInspector.allWindows().map { w -> [String: Any] in
            ["app": w.appName, "bundleID": w.bundleID, "title": w.title,
             "frame": [w.frame.minX, w.frame.minY, w.frame.width, w.frame.height],
             "minimized": w.isMinimized, "fullScreen": w.isFullScreen,
             "screen": Screens.screen(for: w.frame).map(Screens.ref(for:)) ?? "?"]
        }
        let screens = NSScreen.screens.map { s -> [String: Any] in
            let v = Screens.visibleAX(s)
            return ["name": s.localizedName, "ref": Screens.ref(for: s), "visibleAX": [v.minX, v.minY, v.width, v.height]]
        }
        // Raw: all AX windows unfiltered + CG window list, to understand odd apps
        let raw = WindowInspector.regularApps().map { app -> [String: Any] in
            let el = AX.app(app.processIdentifier)
            var v: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(el, "AXWindows" as CFString, &v)
            let wins = (v as? [AXUIElement] ?? []).map { w in
                ["role": AX.string(w, "AXRole") ?? "-", "subrole": AX.string(w, "AXSubrole") ?? "-",
                 "title": AX.string(w, "AXTitle") ?? "-"]
            }
            return ["app": app.localizedName ?? "?", "pid": app.processIdentifier, "axError": err.rawValue, "windows": wins]
        }
        let cg = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
            .map { ["owner": $0[kCGWindowOwnerName as String] ?? "", "pid": $0[kCGWindowOwnerPID as String] ?? 0,
                    "onscreen": $0[kCGWindowIsOnscreen as String] ?? false, "bounds": $0[kCGWindowBounds as String] ?? [:]] }
        let json: [String: Any] = ["trusted": AXPermission.isTrusted, "screens": screens, "windows": rows, "raw": raw, "cg": cg]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: store.url.deletingLastPathComponent().appendingPathComponent("windows.json"))
        }
    }

    private func writeStatus() {
        try? engine.status.write(to: store.url.deletingLastPathComponent().appendingPathComponent("status.txt"),
                                 atomically: true, encoding: .utf8)
    }
}
