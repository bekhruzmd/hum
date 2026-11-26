import SwiftUI

/// Per-display calibration for panel details that macOS does not publish, including pill cutouts.
struct DisplayEdgeSettings: View {
    @Bindable var settings: SettingsStore
    @State private var displays: [DisplayEdgeGeometry] = []
    @State private var selectedID = ""
    @State private var isExpanded = false

    private var selected: DisplayEdgeGeometry? { displays.first { $0.id == selectedID } }
    private var profile: DisplayEdgeProfile { settings.displayEdgeProfiles[selectedID] ?? .init() }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Fit glow to display")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical, 4)

                    Picker("Display", selection: $selectedID) {
                        ForEach(displays, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    if let display = selected {
                        Picker("Camera cutout", selection: binding(\.cutout)) {
                            ForEach(DisplayEdgeProfile.Cutout.allCases) { Text($0.label).tag($0) }
                        }
                        Text(profile.cutout == .automatic
                             ? (display.camera == nil ? "No camera cutout reported by macOS." : "Uses this display’s camera safe area.")
                             : "Adjust the outline to fit this display. Other displays keep their own settings.")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if profile.cutout == .notch || profile.cutout == .pill {
                            LabeledSlider(title: "Cutout width", value: number(\.width, fallback: profile.cutout == .pill ? 120 : Double(display.camera?.width ?? 188)), range: 40...400, step: 1, format: points)
                            LabeledSlider(title: "Cutout height", value: number(\.height, fallback: profile.cutout == .pill ? 28 : Double(display.camera?.height ?? 32)), range: 8...100, step: 1, format: points)
                            if profile.cutout == .pill {
                                LabeledSlider(title: "Gap from top", value: number(\.topGap, fallback: 10), range: 2...80, step: 1, format: points)
                            }
                        }
                        LabeledSlider(title: "Top corners", value: number(\.topRadius, fallback: display.isBuiltIn && (display.camera != nil || profile.cutout == .pill || profile.cutout == .notch) ? 18 : 0), range: 0...80, step: 1, format: points)
                        LabeledSlider(title: "Bottom corners", value: number(\.bottomRadius, fallback: 0), range: 0...80, step: 1, format: points)

                        GeometryReader { proxy in
                            let width = min(300, proxy.size.width)
                            let size = CGSize(width: width, height: width * display.size.height / max(1, display.size.width))
                            ZStack {
                                Color(white: 0.035)
                                DisplayEdgeGlow(contour: display.resolved(profile, in: size), time: 0, intensity: settings.cinematicEdgeGlow)
                            }
                            .frame(width: size.width, height: size.height)
                            .clipped()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Display outline preview")
                        }
                        .frame(height: min(210, 300 * display.size.height / max(1, display.size.width)))

                        Button("Reset this display") { settings.displayEdgeProfiles.removeValue(forKey: selectedID) }
                        Text("Automatic detects the reserved camera area. Use Pill or adjust the corners if the physical outline differs.")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 6)
            }
        }
        .onAppear(perform: refreshDisplays)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in refreshDisplays() }
    }

    private func refreshDisplays() {
        displays = NSScreen.screens.map(DisplayEdgeGeometry.read)
        if !displays.contains(where: { $0.id == selectedID }) {
            selectedID = displays.first(where: \.isBuiltIn)?.id ?? displays.first?.id ?? ""
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<DisplayEdgeProfile, Value>) -> Binding<Value> {
        Binding(get: { profile[keyPath: keyPath] }, set: { value in
            var updated = profile
            updated[keyPath: keyPath] = value
            settings.displayEdgeProfiles[selectedID] = updated
        })
    }

    private func number(_ keyPath: WritableKeyPath<DisplayEdgeProfile, Double?>, fallback: Double) -> Binding<Double> {
        Binding(get: { profile[keyPath: keyPath] ?? fallback }, set: { value in
            var updated = profile
            updated[keyPath: keyPath] = value
            settings.displayEdgeProfiles[selectedID] = updated
        })
    }

    private func points(_ value: Double) -> String { "\(Int(value.rounded())) pt" }
}
