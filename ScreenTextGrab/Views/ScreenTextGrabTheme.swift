import SwiftUI
import AppKit

extension Color {
    // Dynamic "white" — white in dark mode, black in light mode.
    // Replaces hardcoded .white / Color.stgWhite for text and subtle fills.
    static let stgWhite = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white
            : NSColor.black
    })
}

// Make .stgWhite work in ShapeStyle contexts (foregroundStyle, fill, stroke, etc.)
extension ShapeStyle where Self == Color {
    static var stgWhite: Color { Color.stgWhite }
}

extension Color {
    static let surfaceTop = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
    })

    static let surfaceBottom = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.07, green: 0.12, blue: 0.18, alpha: 1.0)
            : NSColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0)
    })

    // MARK: - Accent colors (adjusted for both modes)
    static let accentWarm = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.57, green: 0.73, blue: 0.86, alpha: 1.0)
            : NSColor(red: 0.35, green: 0.50, blue: 0.65, alpha: 1.0)
    })

    static let accentAmber = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.70, green: 0.85, blue: 0.95, alpha: 1.0)
            : NSColor(red: 0.40, green: 0.55, blue: 0.70, alpha: 1.0)
    })

    static let accentCoral = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.47, green: 0.76, blue: 0.90, alpha: 1.0)
            : NSColor(red: 0.25, green: 0.55, blue: 0.72, alpha: 1.0)
    })

    static let accentCool = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.52, green: 0.82, blue: 0.96, alpha: 1.0)
            : NSColor(red: 0.20, green: 0.55, blue: 0.78, alpha: 1.0)
    })

    static let accentMint = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.63, green: 0.90, blue: 0.93, alpha: 1.0)
            : NSColor(red: 0.25, green: 0.60, blue: 0.62, alpha: 1.0)
    })

    static let accentNeutral = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.86, green: 0.93, blue: 0.97, alpha: 1.0)
            : NSColor(red: 0.35, green: 0.40, blue: 0.45, alpha: 1.0)
    })

    static let accentRose = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.51, green: 0.66, blue: 0.80, alpha: 1.0)
            : NSColor(red: 0.35, green: 0.45, blue: 0.60, alpha: 1.0)
    })

    // MARK: - Card styling (dynamic)
    static let cardFill = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.10, green: 0.15, blue: 0.20, alpha: 0.90)
            : NSColor(white: 1.0, alpha: 0.70)
    })

    static let cardStroke = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(white: 0.0, alpha: 0.08)
    })

    // MARK: - Control styling (dynamic)
    static let controlFill = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.96, green: 0.99, blue: 1.0, alpha: 0.055)
            : NSColor(white: 0.0, alpha: 0.04)
    })

    static let controlFillStrong = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.96, green: 0.99, blue: 1.0, alpha: 0.082)
            : NSColor(white: 0.0, alpha: 0.06)
    })

    static let controlStroke = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.80, green: 0.90, blue: 0.98, alpha: 0.12)
            : NSColor(white: 0.0, alpha: 0.10)
    })

    static let controlStrokeStrong = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.80, green: 0.90, blue: 0.98, alpha: 0.18)
            : NSColor(white: 0.0, alpha: 0.15)
    })
}
