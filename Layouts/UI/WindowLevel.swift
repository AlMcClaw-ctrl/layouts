import AppKit
import SwiftUI

/// Keeps the hosting window above all normal windows – even when other apps become active.
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
