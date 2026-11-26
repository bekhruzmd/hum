import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let isFloating: Bool
    let opacity: Double
    var onWindowAvailable: ((NSWindow) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window: window)
            onWindowAvailable?(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window: window)
        }
    }

    private func configure(window: NSWindow) {
        window.level = isFloating ? .floating : .normal
        window.alphaValue = min(max(opacity, 0.35), 1.0)
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }
}
