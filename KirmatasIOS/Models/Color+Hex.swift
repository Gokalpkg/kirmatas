import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Initializes a SwiftUI Color from a 24-bit RGB or 32-bit ARGB hex integer (e.g., 0xFFFFD54F or 0xFFD54F).
    init(hex: UInt32) {
        let a, r, g, b: Double
        if hex > 0xFFFFFF {
            a = Double((hex >> 24) & 0xFF) / 255.0
            r = Double((hex >> 16) & 0xFF) / 255.0
            g = Double((hex >> 8) & 0xFF) / 255.0
            b = Double(hex & 0xFF) / 255.0
        } else {
            a = 1.0
            r = Double((hex >> 16) & 0xFF) / 255.0
            g = Double((hex >> 8) & 0xFF) / 255.0
            b = Double(hex & 0xFF) / 255.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Linearly interpolates between two colors by `t` in [0.0, 1.0].
    static func lerp(_ c1: Color, _ c2: Color, _ t: Double) -> Color {
        let clamped = min(max(t, 0.0), 1.0)
        #if canImport(UIKit)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(c1).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(c2).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            .sRGB,
            red: Double(r1 + (r2 - r1) * CGFloat(clamped)),
            green: Double(g1 + (g2 - g1) * CGFloat(clamped)),
            blue: Double(b1 + (b2 - b1) * CGFloat(clamped)),
            opacity: Double(a1 + (a2 - a1) * CGFloat(clamped))
        )
        #elseif canImport(AppKit)
        let ns1 = NSColor(c1).usingColorSpace(.sRGB) ?? .white
        let ns2 = NSColor(c2).usingColorSpace(.sRGB) ?? .white
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ns1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ns2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            .sRGB,
            red: Double(r1 + (r2 - r1) * CGFloat(clamped)),
            green: Double(g1 + (g2 - g1) * CGFloat(clamped)),
            blue: Double(b1 + (b2 - b1) * CGFloat(clamped)),
            opacity: Double(a1 + (a2 - a1) * CGFloat(clamped))
        )
        #else
        return clamped < 0.5 ? c1 : c2
        #endif
    }
}
