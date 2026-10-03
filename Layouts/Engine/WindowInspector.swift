import AppKit

struct WindowInfo {
    let app: NSRunningApplication
    let element: AXUIElement
    let title: String
    let frame: CGRect
    let isMinimized: Bool
    let isFullScreen: Bool

    var bundleID: String { app.bundleIdentifier ?? "" }
    var appName: String { app.localizedName ?? bundleID }
}

/// Liest die Fenster laufender Apps (vorne → hinten je App).
@MainActor
enum WindowInspector {
    static func windows(of app: NSRunningApplication) -> [WindowInfo] {
        AX.elements(AX.app(app.processIdentifier), "AXWindows").compactMap { el in
            guard AX.string(el, "AXSubrole") == "AXStandardWindow", let frame = AX.frame(el) else { return nil }
            return WindowInfo(app: app, element: el,
                              title: AX.string(el, "AXTitle") ?? "",
                              frame: frame,
                              isMinimized: AX.bool(el, "AXMinimized") ?? false,
                              isFullScreen: AX.bool(el, "AXFullScreen") ?? false)
        }
    }

    /// Fenster aller Instanzen einer App (z. B. Claude privat + Enterprise laufen parallel).
    static func windows(bundleID: String) -> [WindowInfo] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { !$0.isTerminated }
            .flatMap(windows(of:))
    }

    static func regularApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != getpid()
        }
    }

    static func allWindows() -> [WindowInfo] {
        regularApps().flatMap(windows(of:))
    }
}
