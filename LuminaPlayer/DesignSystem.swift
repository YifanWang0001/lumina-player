import SwiftUI

// MARK: - Colors

enum LuminaColor {
    static let background = Color(hex: "000000")
    static let surface = Color(hex: "0D0D0D")
    static let surfaceContainer = Color(hex: "131313")
    static let surfaceContainerLow = Color(hex: "1C1B1B")
    static let surfaceContainerLowest = Color(hex: "0E0E0E")
    static let surfaceContainerHigh = Color(hex: "2A2A2A")

    static let primary = Color(hex: "10A37F")
    static let primaryContainer = Color(hex: "12A480")
    static let onPrimary = Color(hex: "00382A")

    static let onSurface = Color(hex: "ECECEC")
    static let onSurfaceVariant = Color(hex: "B4B4B4")
    static let secondary = Color(hex: "C8C6C6")

    static let border = Color(hex: "2D2D2D")
    static let outlineVariant = Color(hex: "3D4A44")
}

// MARK: - Radius

enum LuminaRadius {
    static let card: CGFloat = 12
    static let button: CGFloat = 12
    static let input: CGFloat = 12
    static let full: CGFloat = 12
}

// MARK: - Font Styles

extension Font {
    static let luminaHeadlineLarge = Font.system(size: 24, weight: .semibold)
    static let luminaHeadlineMedium = Font.system(size: 20, weight: .medium)
    static let luminaBodyLarge = Font.system(size: 16)
    static let luminaBodyMedium = Font.system(size: 14)
    static let luminaLabelSmall = Font.system(size: 12, weight: .medium)
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct LuminaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LuminaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: LuminaRadius.card)
                    .stroke(LuminaColor.border, lineWidth: 1)
            )
    }
}

struct LuminaInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LuminaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.input))
            .overlay(
                RoundedRectangle(cornerRadius: LuminaRadius.input)
                    .stroke(LuminaColor.border, lineWidth: 1)
            )
    }
}

extension View {
    func luminaCard() -> some View {
        modifier(LuminaCard())
    }
    func luminaInput() -> some View {
        modifier(LuminaInput())
    }
}
