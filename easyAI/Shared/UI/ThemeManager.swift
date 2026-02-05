//
//  ThemeManager.swift
//  easyAI
//
//  Global theme selection and palettes.
//

import Foundation
import UIKit
import SwiftUI
import Combine
import RxSwift
import RxCocoa

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var selection: ThemeOption {
        didSet {
            ConfigManager.shared.selectedThemeId = selection.id
            themeRelay.accept(selection)
        }
    }

    let themeRelay: BehaviorRelay<ThemeOption>

    var palette: ThemePalette {
        selection.palette
    }

    var swiftPalette: ThemePaletteSwift {
        ThemePaletteSwift(palette: selection.palette)
    }

    private init() {
        let initialSelection: ThemeOption
        if let stored = ConfigManager.shared.selectedThemeId,
           let theme = ThemeOption(id: stored) {
            initialSelection = theme
        } else {
            initialSelection = .refinedBlue
        }
        self.selection = initialSelection
        self.themeRelay = BehaviorRelay(value: initialSelection)
    }
}

struct ThemePalette {
    let id: String
    let name: String
    let canvas: UIColor
    let canvasSoft: UIColor
    let surface: UIColor
    let surfaceAlt: UIColor
    let border: UIColor
    let textPrimary: UIColor
    let textSecondary: UIColor
    let textTertiary: UIColor
    let accent: UIColor
    let accent2: UIColor
    let shadow: UIColor
}

struct ThemePaletteSwift {
    let canvas: Color
    let canvasSoft: Color
    let surface: Color
    let surfaceAlt: Color
    let border: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let accent2: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [canvas, canvasSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    init(palette: ThemePalette) {
        self.canvas = Color(palette.canvas)
        self.canvasSoft = Color(palette.canvasSoft)
        self.surface = Color(palette.surface)
        self.surfaceAlt = Color(palette.surfaceAlt)
        self.border = Color(palette.border)
        self.textPrimary = Color(palette.textPrimary)
        self.textSecondary = Color(palette.textSecondary)
        self.textTertiary = Color(palette.textTertiary)
        self.accent = Color(palette.accent)
        self.accent2 = Color(palette.accent2)
    }
}

enum ThemeOption: CaseIterable, Identifiable {
    case refinedBlue
    case auroraTeal
    case graphite
    case warmLinen
    case indigo

    var id: String {
        switch self {
        case .refinedBlue: return "refined_blue"
        case .auroraTeal: return "aurora_teal"
        case .graphite: return "graphite"
        case .warmLinen: return "warm_linen"
        case .indigo: return "indigo"
        }
    }

    init?(id: String) {
        switch id {
        case "refined_blue": self = .refinedBlue
        case "aurora_teal": self = .auroraTeal
        case "graphite": self = .graphite
        case "warm_linen": self = .warmLinen
        case "indigo": self = .indigo
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .refinedBlue: return "Refined Blue"
        case .auroraTeal: return "Aurora Teal"
        case .graphite: return "Graphite"
        case .warmLinen: return "Warm Linen"
        case .indigo: return "Indigo"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .refinedBlue:
            return ThemePalette(
                id: id,
                name: name,
                canvas: UIColor(red: 247 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1),
                canvasSoft: UIColor(red: 243 / 255, green: 246 / 255, blue: 255 / 255, alpha: 1),
                surface: .white,
                surfaceAlt: UIColor(red: 243 / 255, green: 244 / 255, blue: 246 / 255, alpha: 1),
                border: UIColor(red: 233 / 255, green: 235 / 255, blue: 240 / 255, alpha: 1),
                textPrimary: UIColor(red: 15 / 255, green: 17 / 255, blue: 21 / 255, alpha: 1),
                textSecondary: UIColor(red: 82 / 255, green: 90 / 255, blue: 100 / 255, alpha: 1),
                textTertiary: UIColor(red: 139 / 255, green: 144 / 255, blue: 152 / 255, alpha: 1),
                accent: UIColor(red: 47 / 255, green: 92 / 255, blue: 255 / 255, alpha: 1),
                accent2: UIColor(red: 107 / 255, green: 140 / 255, blue: 255 / 255, alpha: 1),
                shadow: UIColor.black.withAlphaComponent(0.04)
            )
        case .auroraTeal:
            return ThemePalette(
                id: id,
                name: name,
                canvas: UIColor(red: 246 / 255, green: 249 / 255, blue: 250 / 255, alpha: 1),
                canvasSoft: UIColor(red: 237 / 255, green: 246 / 255, blue: 248 / 255, alpha: 1),
                surface: .white,
                surfaceAlt: UIColor(red: 241 / 255, green: 246 / 255, blue: 247 / 255, alpha: 1),
                border: UIColor(red: 231 / 255, green: 237 / 255, blue: 239 / 255, alpha: 1),
                textPrimary: UIColor(red: 14 / 255, green: 18 / 255, blue: 21 / 255, alpha: 1),
                textSecondary: UIColor(red: 80 / 255, green: 91 / 255, blue: 100 / 255, alpha: 1),
                textTertiary: UIColor(red: 132 / 255, green: 142 / 255, blue: 150 / 255, alpha: 1),
                accent: UIColor(red: 0 / 255, green: 170 / 255, blue: 170 / 255, alpha: 1),
                accent2: UIColor(red: 74 / 255, green: 196 / 255, blue: 188 / 255, alpha: 1),
                shadow: UIColor.black.withAlphaComponent(0.04)
            )
        case .graphite:
            return ThemePalette(
                id: id,
                name: name,
                canvas: UIColor(red: 246 / 255, green: 247 / 255, blue: 248 / 255, alpha: 1),
                canvasSoft: UIColor(red: 238 / 255, green: 240 / 255, blue: 243 / 255, alpha: 1),
                surface: .white,
                surfaceAlt: UIColor(red: 242 / 255, green: 244 / 255, blue: 246 / 255, alpha: 1),
                border: UIColor(red: 228 / 255, green: 231 / 255, blue: 235 / 255, alpha: 1),
                textPrimary: UIColor(red: 16 / 255, green: 18 / 255, blue: 20 / 255, alpha: 1),
                textSecondary: UIColor(red: 88 / 255, green: 95 / 255, blue: 104 / 255, alpha: 1),
                textTertiary: UIColor(red: 140 / 255, green: 146 / 255, blue: 155 / 255, alpha: 1),
                accent: UIColor(red: 84 / 255, green: 96 / 255, blue: 112 / 255, alpha: 1),
                accent2: UIColor(red: 124 / 255, green: 134 / 255, blue: 148 / 255, alpha: 1),
                shadow: UIColor.black.withAlphaComponent(0.04)
            )
        case .warmLinen:
            return ThemePalette(
                id: id,
                name: name,
                canvas: UIColor(red: 250 / 255, green: 248 / 255, blue: 244 / 255, alpha: 1),
                canvasSoft: UIColor(red: 245 / 255, green: 241 / 255, blue: 234 / 255, alpha: 1),
                surface: .white,
                surfaceAlt: UIColor(red: 246 / 255, green: 242 / 255, blue: 236 / 255, alpha: 1),
                border: UIColor(red: 236 / 255, green: 231 / 255, blue: 224 / 255, alpha: 1),
                textPrimary: UIColor(red: 24 / 255, green: 20 / 255, blue: 16 / 255, alpha: 1),
                textSecondary: UIColor(red: 100 / 255, green: 92 / 255, blue: 84 / 255, alpha: 1),
                textTertiary: UIColor(red: 150 / 255, green: 140 / 255, blue: 132 / 255, alpha: 1),
                accent: UIColor(red: 210 / 255, green: 120 / 255, blue: 78 / 255, alpha: 1),
                accent2: UIColor(red: 224 / 255, green: 146 / 255, blue: 106 / 255, alpha: 1),
                shadow: UIColor.black.withAlphaComponent(0.04)
            )
        case .indigo:
            return ThemePalette(
                id: id,
                name: name,
                canvas: UIColor(red: 246 / 255, green: 247 / 255, blue: 251 / 255, alpha: 1),
                canvasSoft: UIColor(red: 238 / 255, green: 241 / 255, blue: 255 / 255, alpha: 1),
                surface: .white,
                surfaceAlt: UIColor(red: 242 / 255, green: 244 / 255, blue: 248 / 255, alpha: 1),
                border: UIColor(red: 229 / 255, green: 232 / 255, blue: 239 / 255, alpha: 1),
                textPrimary: UIColor(red: 14 / 255, green: 16 / 255, blue: 22 / 255, alpha: 1),
                textSecondary: UIColor(red: 82 / 255, green: 89 / 255, blue: 102 / 255, alpha: 1),
                textTertiary: UIColor(red: 136 / 255, green: 142 / 255, blue: 156 / 255, alpha: 1),
                accent: UIColor(red: 92 / 255, green: 89 / 255, blue: 255 / 255, alpha: 1),
                accent2: UIColor(red: 128 / 255, green: 124 / 255, blue: 255 / 255, alpha: 1),
                shadow: UIColor.black.withAlphaComponent(0.04)
            )
        }
    }
}
