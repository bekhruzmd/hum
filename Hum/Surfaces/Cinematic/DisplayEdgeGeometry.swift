import AppKit
import SwiftUI

/// Public screen APIs expose reserved rectangles, not a physical panel outline. Overrides are
/// keyed to a display UUID so calibrating a laptop never puts its camera housing on a monitor.
struct DisplayEdgeProfile: Codable, Equatable, Sendable {
    enum Cutout: String, Codable, CaseIterable, Identifiable {
        case automatic, none, notch, pill
        var id: String { rawValue }
        var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .none: return "No cutout"
            case .notch: return "Notch"
            case .pill: return "Pill"
            }
        }
    }
    var cutout: Cutout = .automatic
    var width: Double? = nil
    var height: Double? = nil
    var topGap: Double? = nil
    var topRadius: Double? = nil
    var bottomRadius: Double? = nil
}

struct DisplayEdgeGeometry: Equatable {
    var id: String = ""
    var name: String = "Display"
    var size: CGSize = CGSize(width: 1512, height: 982)
    /// In display points, with an origin at the upper-left corner.
    var camera: CGRect? = nil
    var isBuiltIn = false

    @MainActor static func read(_ screen: NSScreen) -> Self {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let displayID = CGDirectDisplayID(number?.uint32Value ?? 0)
        let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        let id = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "display-\(displayID)"
        return make(id: id, name: screen.localizedName, frame: screen.frame,
                    safeTop: screen.safeAreaInsets.top, left: screen.auxiliaryTopLeftArea,
                    right: screen.auxiliaryTopRightArea, isBuiltIn: CGDisplayIsBuiltin(displayID) != 0)
    }

    static func make(id: String = "", name: String = "Display", frame: CGRect, safeTop: CGFloat,
                     left: CGRect?, right: CGRect?, isBuiltIn: Bool) -> Self {
        var camera: CGRect?
        if safeTop.isFinite, safeTop > 0, safeTop < frame.height * 0.2,
           let left, let right, left.width > 0, right.width > 0 {
            let x = left.maxX - frame.minX
            let width = right.minX - left.maxX
            if x >= 0, width > 0, x + width <= frame.width {
                camera = CGRect(x: x, y: 0, width: width, height: safeTop)
            }
        }
        return Self(id: id, name: name, size: frame.size, camera: camera, isBuiltIn: isBuiltIn)
    }

    func resolved(_ profile: DisplayEdgeProfile = .init(), in viewSize: CGSize) -> DisplayEdgeContour {
        let sx = max(0, viewSize.width) / max(1, size.width)
        let sy = max(0, viewSize.height) / max(1, size.height)
        let scale = min(sx, sy)
        var cutout = camera
        let pill = profile.cutout == .pill
        if profile.cutout == .none { cutout = nil }
        if profile.cutout == .notch || pill {
            let width = Self.bounded(profile.width, fallback: pill ? 120 : Double(camera?.width ?? 188), upper: Double(size.width * 0.5))
            let height = Self.bounded(profile.height, fallback: pill ? 28 : Double(camera?.height ?? 32), upper: Double(size.height * 0.15))
            let gap = pill ? Self.bounded(profile.topGap, fallback: 10, upper: Double(size.height * 0.1)) : 0
            cutout = CGRect(x: (size.width - width) / 2, y: gap, width: width, height: height)
        }
        let rect = cutout.map { CGRect(x: $0.minX * sx, y: $0.minY * sy, width: $0.width * sx, height: $0.height * sy) } ?? .zero
        // macOS doesn't publish corner radii. Defaults are conservative and can be calibrated.
        let top = Self.bounded(profile.topRadius, fallback: isBuiltIn && cutout != nil ? 18 : 0, upper: 80)
        let bottom = Self.bounded(profile.bottomRadius, fallback: 0, upper: 80)
        return DisplayEdgeContour(size: viewSize, camera: rect, isPill: pill,
                                  topRadius: top * scale, bottomRadius: bottom * scale,
                                  cameraRadius: pill ? rect.height / 2 : min(rect.height * 0.3, 10 * scale),
                                  scale: scale)
    }

    private static func bounded(_ value: Double?, fallback: Double, upper: Double) -> Double {
        min(max(0, upper), max(0, value?.isFinite == true ? value! : fallback))
    }
}

struct DisplayEdgeContour: Equatable {
    var size: CGSize
    var camera: CGRect
    var isPill: Bool
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var cameraRadius: CGFloat
    var scale: CGFloat
}

/// Resolves the screen belonging to this scene's actual window, including secondary displays.
/// Notifications do the work; there is no geometry polling on the animation timeline.
struct DisplayEdgeReader: NSViewRepresentable {
    var onChange: (DisplayEdgeGeometry) -> Void
    func makeNSView(context: Context) -> Reader {
        let view = Reader()
        view.onChange = onChange
        return view
    }
    func updateNSView(_ view: Reader, context: Context) { view.onChange = onChange }

    final class Reader: NSView {
        var onChange: ((DisplayEdgeGeometry) -> Void)?
        private var tokens: [NSObjectProtocol] = []
        private var last: DisplayEdgeGeometry?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens.removeAll()
            guard let window else { return }
            for name in [NSWindow.didChangeScreenNotification, NSWindow.didChangeBackingPropertiesNotification] {
                tokens.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
            }
            tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                  object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
            refresh()
        }
        private func refresh() {
            guard let screen = window?.screen else { return }
            let value = DisplayEdgeGeometry.read(screen)
            guard value != last else { return }
            last = value
            DispatchQueue.main.async { [weak self] in self?.onChange?(value) }
        }
        deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
    }
}
