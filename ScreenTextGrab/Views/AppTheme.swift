import SwiftUI
import AppKit

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.pair("Sistem", "System")
        case .light: return L10n.pair("Açık", "Light")
        case .dark: return L10n.pair("Koyu", "Dark")
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("appearance.themeMode") private(set) var mode: ThemeMode = .system

    var effectiveColorScheme: ColorScheme? {
        mode.colorScheme
    }

    var isDark: Bool {
        switch mode {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    func setMode(_ newMode: ThemeMode) {
        mode = newMode
        objectWillChange.send()
    }
}

// MARK: - Dynamic Colors (Raycast-inspired palette)

extension Color {
    // Background
    static var rayBackground: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                : NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        })
    }

    static var raySurface: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.04)
                : NSColor(white: 0.0, alpha: 0.03)
        })
    }

    static var raySurfaceHover: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.07)
                : NSColor(white: 0.0, alpha: 0.05)
        })
    }

    static var raySurfacePressed: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.10)
                : NSColor(white: 0.0, alpha: 0.07)
        })
    }

    // Text
    static var rayTextPrimary: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.98, alpha: 1.0)
                : NSColor(white: 0.05, alpha: 1.0)
        })
    }

    static var rayTextSecondary: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.65, alpha: 1.0)
                : NSColor(white: 0.35, alpha: 1.0)
        })
    }

    static var rayTextTertiary: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.45, alpha: 1.0)
                : NSColor(white: 0.55, alpha: 1.0)
        })
    }

    // Separators & borders
    static var raySeparator: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.08)
                : NSColor(white: 0.0, alpha: 0.08)
        })
    }

    static var rayBorder: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.10)
                : NSColor(white: 0.0, alpha: 0.10)
        })
    }

    // Accent
    static var rayAccent: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 1.0)
                : NSColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1.0)
        })
    }

    static var rayAccentSoft: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 0.15)
                : NSColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.10)
        })
    }

    // Status colors
    static var raySuccess: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.35, green: 0.78, blue: 0.50, alpha: 1.0)
                : NSColor(red: 0.15, green: 0.60, blue: 0.35, alpha: 1.0)
        })
    }

    static var rayWarning: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.90, green: 0.70, blue: 0.30, alpha: 1.0)
                : NSColor(red: 0.75, green: 0.55, blue: 0.10, alpha: 1.0)
        })
    }

    static var rayDanger: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.90, green: 0.45, blue: 0.45, alpha: 1.0)
                : NSColor(red: 0.80, green: 0.25, blue: 0.25, alpha: 1.0)
        })
    }
}

// MARK: - Raycast-style view modifiers

struct RayCardStyle: ViewModifier {
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.raySurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.rayBorder, lineWidth: 0.5)
            )
    }
}

struct RayRowStyle: ViewModifier {
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
    }
}

extension View {
    func rayCard(padding: CGFloat = 12, cornerRadius: CGFloat = 10) -> some View {
        modifier(RayCardStyle(padding: padding, cornerRadius: cornerRadius))
    }

    func rayRow(hPadding: CGFloat = 10, vPadding: CGFloat = 8) -> some View {
        modifier(RayRowStyle(horizontalPadding: hPadding, verticalPadding: vPadding))
    }
}
