//
//  AppTheme.swift
//  easyAI
//
//  Refined Card Layered theme tokens (Light only).
//

import UIKit
import SwiftUI

enum AppTheme {
    private static var palette: ThemePalette { ThemeManager.shared.palette }

    static var canvas: UIColor { palette.canvas }
    static var canvasSoft: UIColor { palette.canvasSoft }
    static var surface: UIColor { palette.surface }
    static var surfaceAlt: UIColor { palette.surfaceAlt }
    static var border: UIColor { palette.border }
    static var textPrimary: UIColor { palette.textPrimary }
    static var textSecondary: UIColor { palette.textSecondary }
    static var textTertiary: UIColor { palette.textTertiary }
    static var accent: UIColor { palette.accent }
    static var accent2: UIColor { palette.accent2 }
    static var shadow: UIColor { palette.shadow }

    static let cardCornerRadius: CGFloat = 16
    static let bubbleCornerRadius: CGFloat = 16
    static let inputCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 18
    static let borderWidth: CGFloat = 0.8
    static let shadowRadius: CGFloat = 18
    static let shadowOffset = CGSize(width: 0, height: 6)

    static var titleFont: UIFont {
        let base = UIFont.systemFont(ofSize: 20, weight: .medium)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: base.pointSize)
        }
        return base
    }
}

enum AppThemeSwift {
    private static var palette: ThemePaletteSwift { ThemeManager.shared.swiftPalette }

    static var canvas: Color { palette.canvas }
    static var canvasSoft: Color { palette.canvasSoft }
    static var surface: Color { palette.surface }
    static var surfaceAlt: Color { palette.surfaceAlt }
    static var border: Color { palette.border }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var textTertiary: Color { palette.textTertiary }
    static var accent: Color { palette.accent }
    static var accent2: Color { palette.accent2 }

    static let titleFont = Font.system(size: 20, weight: .medium, design: .serif)

    static var backgroundGradient: LinearGradient { palette.backgroundGradient }
    static var accentGradient: LinearGradient { palette.accentGradient }
}
