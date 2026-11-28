import SwiftUI

/// A small confirmation that slides in and goes away on its own.
struct HumToast: View {
    struct Message: Equatable {
        let id = UUID()
        let text: String
        let symbol: String
    }

    let message: Message

    var body: some View {
        Label(message.text, systemImage: message.symbol)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The outline shown while a file is dragged over a window that accepts it.
struct DropHighlight: View {
    let label: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            Label(label, systemImage: "text.badge.plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(8)
        .allowsHitTesting(false)
    }
}
