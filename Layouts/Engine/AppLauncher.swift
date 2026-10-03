import AppKit

/// Launches apps and opens new windows.
@MainActor
enum AppLauncher {
    static let newWindowTitles: Set<String> = ["New Window", "Neues Fenster"]

    static func running(_ bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first { !$0.isTerminated }
    }

    /// If the app isn't running, launch it and briefly wait for its first window.
    static func ensureRunning(_ bundleID: String) async -> NSRunningApplication? {
        if let app = running(bundleID) { return app }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = false
        guard (try? await NSWorkspace.shared.openApplication(at: url, configuration: cfg)) != nil else { return nil }
        let app = await poll(timeout: 5) { running(bundleID) }
        if let app {
            _ = await poll(timeout: 6) { WindowInspector.windows(of: app).isEmpty ? nil : true }
        }
        return app
    }

    /// Opens a new window and returns it once it appears.
    static func openWindow(for slot: Slot, app: NSRunningApplication) async -> AXUIElement? {
        let before = WindowInspector.windows(of: app).map(\.element)
        let spec = slot.launch ?? LaunchSpec(kind: .newWindow)

        switch spec.kind {
        case .newWindow:
            if let item = AX.menuItem(pid: app.processIdentifier, titles: newWindowTitles) {
                AX.perform(item, "AXPress")
            } else {
                sendCommandN(to: app)
            }
        case .url:
            guard let s = spec.url, let url = URL(string: s), let appURL = app.bundleURL else { return nil }
            let cfg = NSWorkspace.OpenConfiguration()
            if isChromium(slot.bundleID) {
                // Chromium forwards the arguments to the running instance → a real new window.
                cfg.createsNewApplicationInstance = true
                cfg.arguments = ["--new-window", s]
                _ = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: cfg)
            } else {
                _ = try? await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg)
            }
        case .terminal:
            runInTerminal(cwd: spec.cwd, command: spec.command, title: slot.match.title)
        }

        return await poll(timeout: 6) {
            WindowInspector.windows(of: app).first { !AX.contains(before, $0.element) }?.element
        }
    }

    static func poll<T>(timeout: Double, every ms: Int = 100, _ body: () -> T?) async -> T? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let v = body() { return v }
            try? await Task.sleep(for: .milliseconds(ms))
        }
        return body()
    }

    private static func isChromium(_ id: String) -> Bool {
        ["com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac", "company.thebrowser.Browser"].contains(id)
    }

    private static func sendCommandN(to app: NSRunningApplication) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 0x2D, keyDown: down)  // N
            e?.flags = .maskCommand
            e?.postToPid(app.processIdentifier)
        }
    }

    private static func runInTerminal(cwd: String?, command: String?, title: String?) {
        func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        var parts: [String] = []
        if let title { parts.append("printf '\\e]0;%s\\a' \(q(title))") }
        if let cwd { parts.append("cd \(q((cwd as NSString).expandingTildeInPath))") }
        if let command { parts.append(command) }
        let shell = parts.joined(separator: " && ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"Terminal\" to do script \"\(shell)\""
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err { NSLog("Layouts: Terminal AppleScript failed: \(err)") }
    }
}
