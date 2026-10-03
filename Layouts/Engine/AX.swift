import AppKit
import ApplicationServices

/// Dünne Hülle um die Accessibility-API.
@MainActor
enum AX {
    static func app(_ pid: pid_t) -> AXUIElement {
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(el, 1.0)  // hängende Apps blockieren uns nicht
        return el
    }

    static func value(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
        return v
    }

    static func string(_ el: AXUIElement, _ attr: String) -> String? { value(el, attr) as? String }
    static func bool(_ el: AXUIElement, _ attr: String) -> Bool? { value(el, attr) as? Bool }
    static func elements(_ el: AXUIElement, _ attr: String) -> [AXUIElement] {
        value(el, attr) as? [AXUIElement] ?? []
    }

    static func element(_ el: AXUIElement, _ attr: String) -> AXUIElement? {
        guard let v = value(el, attr), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    @discardableResult
    static func set(_ el: AXUIElement, _ attr: String, _ v: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(el, attr as CFString, v) == .success
    }

    @discardableResult
    static func perform(_ el: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(el, action as CFString) == .success
    }

    /// Fensterrahmen in AX-Koordinaten (Ursprung oben links am Hauptbildschirm).
    static func frame(_ el: AXUIElement) -> CGRect? {
        guard let p = value(el, "AXPosition"), let s = value(el, "AXSize"),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &origin)
        AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    /// Größe → Position → Größe: sonst begrenzt macOS die Größe am alten Bildschirmrand.
    static func setFrame(_ el: AXUIElement, _ r: CGRect) {
        var size = r.size, origin = r.origin
        guard let s = AXValueCreate(.cgSize, &size), let p = AXValueCreate(.cgPoint, &origin) else { return }
        set(el, "AXSize", s)
        set(el, "AXPosition", p)
        set(el, "AXSize", s)
    }

    /// Sucht einen Menüeintrag (z. B. „Neues Fenster“) in der Menüleiste der App.
    static func menuItem(pid: pid_t, titles: Set<String>) -> AXUIElement? {
        guard let bar = element(app(pid), "AXMenuBar") else { return nil }
        var queue: [(AXUIElement, Int)] = [(bar, 0)]
        while !queue.isEmpty {
            let (el, depth) = queue.removeFirst()
            for child in elements(el, "AXChildren") {
                if string(child, "AXRole") == "AXMenuItem",
                   let t = string(child, "AXTitle"), titles.contains(t),
                   bool(child, "AXEnabled") != false {
                    return child
                }
                if depth < 3 { queue.append((child, depth + 1)) }
            }
        }
        return nil
    }

    static func contains(_ list: [AXUIElement], _ el: AXUIElement) -> Bool {
        list.contains { CFEqual($0, el) }
    }
}
