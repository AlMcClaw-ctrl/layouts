import AppKit
import SwiftUI

/// Hält das umgebende Fenster über allen normalen Fenstern – auch wenn andere Apps aktiv werden.
struct WindowLevel: NSViewRepresentable {
    var floating: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { apply(view.window) }
    }

    private func apply(_ window: NSWindow?) {
        guard let window else { return }
        window.level = floating ? .floating : .normal
        window.hidesOnDeactivate = false
    }
}
