import SwiftUI
import AppKit

// MARK: - Sharp Geometric Design System
// Zero border radius, emerald green, Manrope font, bold confidence

enum Theme {
    
    // MARK: - Colors
    
    enum Colors {
        // Primary
        static let sharpGreen = Color(hex: "10B981")
        static let darkGreen = Color(hex: "059669")
        static let accentGreen = Color(hex: "34D399")
        static let lightGreen = Color(hex: "D1FAE5")
        
        // Neutral
        static let background = Color.white
        static let secondaryBackground = Color(hex: "F3F4F6")
        static let textPrimary = Color(hex: "111827")
        static let textSecondary = Color(hex: "6B7280")
        static let border = Color(hex: "E5E7EB")
        
        // Status
        static let success = sharpGreen
        static let error = Color(hex: "EF4444")
        static let warning = Color(hex: "F59E0B")
        static let recording = Color(hex: "EF4444")
        static let processing = Color(hex: "3B82F6")
        
        // NSColor variants for AppKit
        enum NS {
            static let sharpGreen = NSColor(hex: "10B981")
            static let darkGreen = NSColor(hex: "059669")
            static let textPrimary = NSColor(hex: "111827")
            static let textSecondary = NSColor(hex: "6B7280")
            static let background = NSColor.white
            static let secondaryBackground = NSColor(hex: "F3F4F6")
            static let border = NSColor(hex: "E5E7EB")
            static let recording = NSColor(hex: "EF4444")
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Font name - Manrope (falls back to system if not installed)
        static let fontName = "Manrope"
        
        // Weights
        static let regular: Font.Weight = .regular      // 400
        static let medium: Font.Weight = .medium        // 500
        static let semibold: Font.Weight = .semibold    // 600
        static let bold: Font.Weight = .bold            // 700
        static let extrabold: Font.Weight = .heavy      // 800
        
        // Sizes
        static let heroSize: CGFloat = 56
        static let h1Size: CGFloat = 40
        static let h2Size: CGFloat = 28
        static let h3Size: CGFloat = 17.6
        static let bodyLarge: CGFloat = 17.6
        static let body: CGFloat = 14.4
        static let caption: CGFloat = 12.8
        static let small: CGFloat = 10.4
        
        // Font helpers
        static func hero() -> Font {
            .system(size: heroSize, weight: extrabold)
        }
        
        static func h1() -> Font {
            .system(size: h1Size, weight: extrabold)
        }
        
        static func h2() -> Font {
            .system(size: h2Size, weight: extrabold)
        }
        
        static func h3() -> Font {
            .system(size: h3Size, weight: bold)
        }
        
        static func bodyLargeFont() -> Font {
            .system(size: bodyLarge, weight: regular)
        }
        
        static func bodyFont() -> Font {
            .system(size: body, weight: regular)
        }
        
        static func label() -> Font {
            .system(size: caption, weight: bold)
        }
        
        static func captionFont() -> Font {
            .system(size: caption, weight: regular)
        }
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 48
    }
    
    // MARK: - Animation
    
    static let animation = Animation.easeOut(duration: 0.2)
}

// MARK: - Color Extensions

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
            (a, r, g, b) = (1, 1, 1, 0)
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

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 0)
        }
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Button Styles

/// Primary button - Sharp green, no border radius
struct SharpPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                configuration.isPressed 
                    ? Theme.Colors.darkGreen 
                    : (isEnabled ? Theme.Colors.sharpGreen : Theme.Colors.textSecondary)
            )
            .animation(Theme.animation, value: configuration.isPressed)
    }
}

/// Secondary button - Outlined, sharp edges
struct SharpSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(
                configuration.isPressed 
                    ? Theme.Colors.sharpGreen 
                    : Theme.Colors.textPrimary
            )
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .background(Color.clear)
            .overlay(
                Rectangle()
                    .stroke(
                        configuration.isPressed 
                            ? Theme.Colors.sharpGreen 
                            : Theme.Colors.textPrimary, 
                        lineWidth: 2
                    )
            )
            .animation(Theme.animation, value: configuration.isPressed)
    }
}

/// Ghost button - Minimal, text only
struct SharpGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(
                configuration.isPressed 
                    ? Theme.Colors.sharpGreen 
                    : Theme.Colors.textSecondary
            )
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .animation(Theme.animation, value: configuration.isPressed)
    }
}

/// Danger button - Red, for destructive actions
struct SharpDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Theme.Colors.error)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .animation(Theme.animation, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply sharp card styling
    func sharpCard() -> some View {
        self
            .padding(Theme.Spacing.xxl)
            .background(Theme.Colors.background)
            .overlay(
                Rectangle()
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
    
    /// Apply sharp panel styling (secondary background)
    func sharpPanel() -> some View {
        self
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.secondaryBackground)
    }
    
    /// Sharp divider
    func sharpDivider() -> some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 1)
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == SharpPrimaryButtonStyle {
    static var sharpPrimary: SharpPrimaryButtonStyle { SharpPrimaryButtonStyle() }
}

extension ButtonStyle where Self == SharpSecondaryButtonStyle {
    static var sharpSecondary: SharpSecondaryButtonStyle { SharpSecondaryButtonStyle() }
}

extension ButtonStyle where Self == SharpGhostButtonStyle {
    static var sharpGhost: SharpGhostButtonStyle { SharpGhostButtonStyle() }
}

extension ButtonStyle where Self == SharpDangerButtonStyle {
    static var sharpDanger: SharpDangerButtonStyle { SharpDangerButtonStyle() }
}
