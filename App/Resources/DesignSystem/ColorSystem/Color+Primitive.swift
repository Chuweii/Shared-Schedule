//
//  Color+Primitive.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/3/1.
//

import SwiftUI
import UIKit

extension ShapeStyle where Self == Color {
    static var brandPrimary: Color { .brandPrimary }
    static var gray0: Color { .gray0 }
    static var gray50: Color { .gray50 }
    static var gray100: Color { .gray100 }
    static var gray300: Color { .gray300 }
    static var gray400: Color { .gray400 }
    static var gray500: Color { .gray500 }
    static var gray600: Color { .gray600 }
    static var gray700: Color { .gray700 }
    static var gray800: Color { .gray800 }
    static var gray1000: Color { .gray1000 }
    static var blue500: Color { .blue500 }
    static var blue50: Color { .blue50 }
    static var green500: Color { .green500 }
    static var green50: Color { .green50 }
    static var orange500: Color { .orange500 }
    static var orange50: Color { .orange50 }
    static var red500: Color { .red500 }
    static var red50: Color { .red50 }
    static var mask70: Color { .mask70 }
    static var mask30: Color { .mask30 }
}

// MARK: - Color Extension

extension Color {
    // MARK: - Brand Color

    static let brandPrimary = Color(hex: "#111111")

    // MARK: - Gray Color

    static let gray0 = Color(hex: "#FFFFFF")

    static let gray50 = Color(hex: "#F7F7F7")

    static let gray100 = Color(hex: "#F1F1F1")

    static let gray300 = Color(hex: "#D4D4D4")

    static let gray400 = Color(hex: "#A3A3A3")

    static let gray500 = Color(hex: "#737373")

    static let gray600 = Color(hex: "#525252")

    static let gray700 = Color(hex: "#404040")

    static let gray800 = Color(hex: "#232323")
    
    static let gray1000 = Color(hex: "#0A0A0A")

    // MARK: - Secondary Color

    static let blue500 = Color(hex: "#0080FF")
    
    static let blue50 = Color(hex: "#F5F9FF")
    
    static let green500 = Color(hex: "#1AAD19")
    
    static let green50 = Color(hex: "#F6FFF9")

    static let orange500 = Color(hex: "#FA9E14")

    static let orange50 = Color(hex: "#FFF8EC")
    
    static let red500 = Color(hex: "#DD4B39")

    static let red50 = Color(hex: "#FFF5F3")

    // MARK: - Mask

    static let mask70 = Color.black.opacity(0.7)

    static let mask30 = Color.black.opacity(0.3)
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
    
    /// Extension color initialization for the color that requires adjustment opacity
    init(hex: String, opacity: Double) {
        let base = Color(hex: hex)
        self = base.opacity(opacity)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(red: CGFloat(r) / 255,
                  green: CGFloat(g) / 255,
                  blue: CGFloat(b) / 255,
                  alpha: CGFloat(a) / 255)
    }
}

