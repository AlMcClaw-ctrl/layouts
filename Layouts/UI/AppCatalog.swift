import AppKit
import SwiftUI

/// Namen, Icons und Farben für Apps im Editor.
@MainActor
enum AppCatalog {
    struct Entry: Hashable, Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    private static var icons: [String: NSImage] = [:]

    static func icon(_ bundleID: String) -> NSImage? {
        if let cached = icons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = image
        return image
    }

    static func name(_ bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = app.localizedName { return name }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    /// Laufende Apps mit Fenstern, alphabetisch.
    static func runningApps() -> [Entry] {
        WindowInspector.regularApps()
            .compactMap { app in app.bundleIdentifier.map { Entry(bundleID: $0, name: app.localizedName ?? $0) } }
            .uniqued()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Stabile Farbe pro App (String.hashValue ist pro Start zufällig, darum djb2).
    static func color(_ bundleID: String) -> Color {
        let hash = bundleID.utf8.reduce(UInt32(5381)) { ($0 << 5) &+ $0 &+ UInt32($1) }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.55, brightness: 0.85)
    }
}
