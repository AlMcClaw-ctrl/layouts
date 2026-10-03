import AppKit

/// Bildschirme auflösen und zwischen AppKit- und AX-Koordinaten umrechnen.
/// AppKit: Ursprung unten links. AX: Ursprung oben links. Bezug ist jeweils der Hauptbildschirm.
@MainActor
enum Screens {
    static var primary: NSScreen? { NSScreen.screens.first }

    static func toAX(_ r: CGRect) -> CGRect {
        let h = primary?.frame.height ?? 0
        return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

    /// Sichtbarer Bereich (ohne Menüleiste/Dock) in AX-Koordinaten.
    static func visibleAX(_ screen: NSScreen) -> CGRect { toAX(screen.visibleFrame) }

    static func uuid(_ screen: NSScreen) -> String? {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, cf) as String
    }

    /// Kennung der aktuellen Bildschirm-Kombination.
    static var signature: [String] { NSScreen.screens.compactMap(uuid).sorted() }

    static func describe(_ signature: [String]) -> String {
        let names = signature.map { id in NSScreen.screens.first { uuid($0) == id }?.localizedName ?? "nicht verbunden" }
        return names.count == 1 ? names[0] : "\(names.count) Bildschirme: " + names.joined(separator: " + ")
    }

    static func resolve(_ ref: String) -> NSScreen? {
        if ref == "main" { return primary }
        return NSScreen.screens.first { uuid($0) == ref }
            ?? NSScreen.screens.first { $0.localizedName == ref }
            ?? primary
    }

    static func ref(for screen: NSScreen) -> String {
        screen == primary ? "main" : (uuid(screen) ?? screen.localizedName)
    }

    /// Bildschirm mit der größten Überlappung zu einem AX-Rahmen.
    static func screen(for axRect: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            area(visibleAX(a).intersection(axRect)) < area(visibleAX(b).intersection(axRect))
        }
    }

    static func absolute(_ u: UnitRect, on screen: NSScreen) -> CGRect {
        let v = visibleAX(screen)
        return CGRect(x: (v.minX + u.x * v.width).rounded(), y: (v.minY + u.y * v.height).rounded(),
                      width: (u.w * v.width).rounded(), height: (u.h * v.height).rounded())
    }

    static func relative(_ r: CGRect, on screen: NSScreen) -> UnitRect {
        let v = visibleAX(screen)
        func q(_ x: Double) -> Double { (min(max(x, 0), 1) * 1000).rounded() / 1000 }
        return UnitRect(x: q((r.minX - v.minX) / v.width), y: q((r.minY - v.minY) / v.height),
                        w: q(r.width / v.width), h: q(r.height / v.height))
    }

    private static func area(_ r: CGRect) -> CGFloat { r.isNull ? 0 : r.width * r.height }
}
