import SwiftUI

// MARK: - Retro Pixel Art Icons
/// Native 8-bit retro pixel icons rendered without any emojis.

public struct PixelCoin: View {
    public let size: CGFloat

    public init(size: CGFloat = 16.0) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let pixelSize = canvasSize.width / 8.0
            // 8x8 Gold Coin Matrix:
            // 0: transparent, 1: dark rim, 2: golden body, 3: bright shine
            let matrix: [[Int]] = [
                [0, 1, 1, 1, 1, 1, 1, 0],
                [1, 3, 3, 2, 2, 2, 1, 1],
                [1, 3, 2, 2, 2, 2, 1, 1],
                [1, 2, 2, 3, 3, 2, 1, 1],
                [1, 2, 2, 3, 3, 2, 1, 1],
                [1, 2, 2, 2, 2, 2, 1, 1],
                [1, 1, 1, 1, 1, 1, 1, 1],
                [0, 1, 1, 1, 1, 1, 1, 0]
            ]

            for r in 0..<8 {
                for c in 0..<8 {
                    let val = matrix[r][c]
                    guard val > 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(c) * pixelSize,
                        y: CGFloat(r) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    let color: Color
                    switch val {
                    case 3: color = Color(hex: 0xFFFFF9C4) // Shine highlight
                    case 2: color = Color(hex: 0xFFFFD54F) // Gold body
                    default: color = Color(hex: 0xFFE65100) // Deep gold rim
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

public struct PixelFood: View {
    public let size: CGFloat

    public init(size: CGFloat = 16.0) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let pixelSize = canvasSize.width / 8.0
            // 8x8 Grain/Pellet Matrix:
            let matrix: [[Int]] = [
                [0, 0, 1, 1, 0, 0, 0, 0],
                [0, 1, 2, 2, 1, 0, 0, 0],
                [0, 1, 3, 2, 2, 1, 0, 0],
                [1, 2, 3, 2, 2, 2, 1, 0],
                [1, 2, 2, 2, 2, 2, 1, 0],
                [0, 1, 2, 2, 2, 1, 0, 0],
                [0, 0, 1, 1, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0]
            ]

            for r in 0..<8 {
                for c in 0..<8 {
                    let val = matrix[r][c]
                    guard val > 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(c) * pixelSize,
                        y: CGFloat(r) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    let color: Color
                    switch val {
                    case 3: color = Color(hex: 0xFFC8E6C9) // Green sprout highlight
                    case 2: color = Color(hex: 0xFF81C784) // Vibrant leaf
                    default: color = Color(hex: 0xFF2E7D32) // Outline
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

public struct PixelFishIcon: View {
    public let size: CGFloat

    public init(size: CGFloat = 16.0) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let pixelSize = canvasSize.width / 8.0
            let matrix: [[Int]] = [
                [0, 0, 0, 1, 1, 0, 0, 0],
                [0, 0, 1, 2, 2, 1, 0, 1],
                [1, 1, 2, 3, 2, 2, 1, 1],
                [1, 2, 2, 2, 2, 2, 2, 1],
                [1, 2, 2, 2, 2, 2, 2, 1],
                [1, 1, 2, 2, 2, 2, 1, 1],
                [0, 0, 1, 2, 2, 1, 0, 1],
                [0, 0, 0, 1, 1, 0, 0, 0]
            ]

            for r in 0..<8 {
                for c in 0..<8 {
                    let val = matrix[r][c]
                    guard val > 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(c) * pixelSize,
                        y: CGFloat(r) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    let color: Color
                    switch val {
                    case 3: color = .white                 // Eye catchlight
                    case 2: color = Color(hex: 0xFF00E5FF) // Aqua scales
                    default: color = Color(hex: 0xFF006064) // Outline
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}
