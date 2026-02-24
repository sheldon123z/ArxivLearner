import SwiftUI
import UIKit

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
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

// MARK: - Adaptive Color

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - AppTheme

enum AppTheme {

    // MARK: Colors (adaptive light/dark)

    static let primary = Color(light: Color(hex: "6C5CE7"), dark: Color(hex: "A29BFE"))
    static let secondary = Color(light: Color(hex: "00CEC9"), dark: Color(hex: "55EFC4"))
    static let accent = Color(light: Color(hex: "FD79A8"), dark: Color(hex: "FD79A8"))
    static let background = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let surfaceElevated = Color(UIColor.tertiarySystemBackground)

    // MARK: Tag Preset Colors

    static let tagPresetColors: [String] = [
        "6C5CE7", "00CEC9", "FD79A8", "FDCB6E", "E17055",
        "00B894", "0984E3", "6C5CE7", "E84393", "2D3436"
    ]

    // MARK: Category Colors

    static let categoryColors: [String: Color] = [
        "cs.AI": Color(hex: "6C5CE7"),
        "cs.LG": Color(hex: "00CEC9"),
        "cs.CV": Color(hex: "FD79A8"),
        "cs.CL": Color(hex: "FDCB6E"),
        "cs.RO": Color(hex: "E17055")
    ]

    static func categoryColor(for category: String) -> Color {
        categoryColors[category] ?? Color(UIColor.systemGray)
    }

    // MARK: Dimensions

    static let cardCornerRadius:    CGFloat = 16
    static let cardPadding:         CGFloat = 16
    static let cardShadowRadius:    CGFloat = 8
    static let compactCardHeight:   CGFloat = 120
    static let buttonCornerRadius:  CGFloat = 10
    static let spacing:             CGFloat = 12
}
