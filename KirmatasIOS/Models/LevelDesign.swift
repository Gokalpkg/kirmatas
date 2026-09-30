import Foundation
import SwiftUI

enum LevelDesign {
    static let shapeSmiley: [[Int]] = [
        [0, 1, 1, 1, 1, 1, 0],
        [1, 0, 1, 0, 1, 0, 1],
        [1, 0, 0, 0, 0, 0, 1],
        [1, 0, 1, 0, 1, 0, 1],
        [1, 0, 0, 1, 0, 0, 1],
        [0, 1, 1, 0, 1, 1, 0]
    ]

    static let shapeSword: [[Int]] = [
        [0, 0, 0, 1, 0, 0, 0],
        [0, 0, 0, 1, 0, 0, 0],
        [0, 0, 0, 1, 0, 0, 0],
        [0, 1, 1, 1, 1, 1, 0],
        [0, 0, 0, 1, 0, 0, 0],
        [0, 0, 1, 1, 1, 0, 0]
    ]

    static let shapeHeart: [[Int]] = [
        [0, 1, 1, 0, 1, 1, 0],
        [1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 0],
        [0, 0, 1, 1, 1, 0, 0],
        [0, 0, 0, 1, 0, 0, 0]
    ]

    static let shapeDiamond: [[Int]] = [
        [0, 0, 0, 1, 0, 0, 0],
        [0, 0, 1, 1, 1, 0, 0],
        [0, 1, 1, 1, 1, 1, 0],
        [1, 1, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 0],
        [0, 0, 1, 1, 1, 0, 0],
        [0, 0, 0, 1, 0, 0, 0]
    ]

    static let magmaPalette: [Color] = [
        Color(hex: 0xFFFF3D00),
        Color(hex: 0xFFFF6D00),
        Color(hex: 0xFFFF9100),
        Color(hex: 0xFFD84315),
        Color(hex: 0xFFBF360C),
        Color(hex: 0xFFFF5722)
    ]

    static let icePalette: [Color] = [
        Color(hex: 0xFFE1F5FE),
        Color(hex: 0xFF81D4FA),
        Color(hex: 0xFF4FC3F7),
        Color(hex: 0xFF29B6F6),
        Color(hex: 0xFFB3E5FC),
        Color(hex: 0xFF80DEEA)
    ]

    static let candyPalette: [Color] = [
        Color(hex: 0xFFFF4081),
        Color(hex: 0xFFE040FB),
        Color(hex: 0xFF7C4DFF),
        Color(hex: 0xFFFF80AB),
        Color(hex: 0xFFEA80FC),
        Color(hex: 0xFFB388FF)
    ]

    static let tuftPalette: [Color] = [
        Color(hex: 0xFFFF7043),
        Color(hex: 0xFFFFD54F),
        Color(hex: 0xFF4DD0E1),
        Color(hex: 0xFF81C784),
        Color(hex: 0xFFBA68C8),
        Color(hex: 0xFFFF8A80),
        Color(hex: 0xFF4FC3F7),
        Color(hex: 0xFFAED581)
    ]

    static let baseTopMargin: Double = 105.0

    static func buildClassicLevel(level: Int, screenWidth: Double, screenHeight: Double) -> [Brick] {
        var bricks: [Brick] = []
        let isBossLevel = (level % 5 == 0)

        if isBossLevel {
            let bossW = screenWidth * 0.52
            let bossH = 38.0
            let bossX = (screenWidth - bossW) / 2.0
            let bossHp = 15 + level * 3

            bricks.append(
                Brick(
                    x: bossX,
                    y: baseTopMargin + 10,
                    width: bossW,
                    height: bossH,
                    hp: bossHp,
                    maxHp: bossHp,
                    minX: 16.0,
                    maxX: screenWidth - 16.0,
                    isBoss: true,
                    bossVx: 75.0 + Double(level) * 2.0,
                    color: Color(hex: 0xFFFF1744),
                    points: 500
                )
            )

            // Guard bricks in front of the boss
            let cols = 6
            let gap = 6.0
            let bw = (screenWidth - 48.0 - gap * Double(cols - 1)) / Double(cols)
            let totalW = Double(cols) * bw + gap * Double(cols - 1)
            let startX = (screenWidth - totalW) / 2.0

            for c in 0..<cols {
                bricks.append(
                    Brick(
                        x: startX + Double(c) * (bw + gap),
                        y: baseTopMargin + bossH + 30.0,
                        width: bw,
                        height: 20.0,
                        hp: 2,
                        maxHp: 2,
                        color: Color(hex: 0xFFFF9100),
                        points: 25
                    )
                )
            }
            return bricks
        }

        // Generate procedural symmetric shape
        var rng = SeededGenerator(seed: UInt64(level * 999))
        let rows = 4 + (level % 4) // 4 to 7 rows
        let cols = 7
        var matrix = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        
        for r in 0..<rows {
            for c in 0...(cols / 2) {
                // 75% chance to place a brick, making fun abstract shapes
                if rng.nextDouble() > 0.25 {
                    matrix[r][c] = 1
                    matrix[r][cols - 1 - c] = 1 // Mirror for symmetry
                }
            }
        }
        
        // Ensure at least some bricks exist
        if matrix.flatMap({ $0 }).filter({ $0 == 1 }).isEmpty {
            matrix[0][cols/2] = 1
        }

        let gap = 6.0
        let bw = (screenWidth - 40.0 - gap * Double(cols - 1)) / Double(cols)
        let totalW = Double(cols) * bw + gap * Double(cols - 1)
        let startX = (screenWidth - totalW) / 2.0
        let bh = 22.0

        for r in 0..<rows {
            for c in 0..<cols {
                if matrix[r][c] == 1 {
                        let color = magmaPalette[(r + c) % magmaPalette.count]
                        let isSteel = (level > 3 && r == 0 && (c == 0 || c == cols - 1))
                        let isMover = (level > 6 && r == rows - 1 && c == 2)
                        let brickHp = isSteel ? 999 : (level > 2 ? (r % 2 + 1) : 1)

                        bricks.append(
                            Brick(
                                x: startX + Double(c) * (bw + gap),
                                y: baseTopMargin + Double(r) * (bh + gap),
                                width: bw,
                                height: bh,
                                hp: brickHp,
                                maxHp: brickHp,
                                isSteel: isSteel,
                                isMover: isMover,
                                minX: 16.0,
                                maxX: screenWidth - 16.0,
                                color: isSteel ? Color(hex: 0xFFCFD8DC) : color,
                                points: isSteel ? 0 : 20
                            )
                        )
                    }
                }
            }
        return bricks
    }

    static func buildZenLevel(screenWidth: Double, screenHeight: Double) -> [Brick] {
        var bricks: [Brick] = []
        let rows = 4
        let cols = 6
        let gap = 8.0
        let bw = (screenWidth - 36.0 - gap * Double(cols - 1)) / Double(cols)
        let totalW = Double(cols) * bw + gap * Double(cols - 1)
        let startX = (screenWidth - totalW) / 2.0
        let bh = 24.0

        for r in 0..<rows {
            for c in 0..<cols {
                let color = candyPalette[(r * cols + c) % candyPalette.count]
                bricks.append(
                    Brick(
                        x: startX + Double(c) * (bw + gap),
                        y: baseTopMargin + Double(r) * (bh + gap),
                        width: bw,
                        height: bh,
                        hp: 1,
                        maxHp: 1,
                        color: color,
                        points: 10
                    )
                )
            }
        }
        return bricks
    }

    static func buildDescendInitial(screenWidth: Double, screenHeight: Double) -> [Brick] {
        var bricks: [Brick] = []
        let rows = 4
        for r in 0..<rows {
            bricks.append(contentsOf: buildDescendRow(rowIndex: r, screenWidth: screenWidth, screenHeight: screenHeight))
        }
        return bricks
    }

    static func buildDescendRow(rowIndex: Int, screenWidth: Double, screenHeight: Double) -> [Brick] {
        var rowBricks: [Brick] = []
        let cols = 7
        let gap = 6.0
        let bw = (screenWidth - 32.0 - gap * Double(cols - 1)) / Double(cols)
        let totalW = Double(cols) * bw + gap * Double(cols - 1)
        let startX = (screenWidth - totalW) / 2.0
        let bh = 22.0
        let rowStep = bh + gap // 28.0

        let color = magmaPalette[rowIndex % magmaPalette.count]
        for c in 0..<cols {
            rowBricks.append(
                Brick(
                    x: startX + Double(c) * (bw + gap),
                    y: baseTopMargin + Double(rowIndex) * rowStep,
                    width: bw,
                    height: bh,
                    hp: 1,
                    maxHp: 1,
                    color: color,
                    points: 15
                )
            )
        }
        return rowBricks
    }

    static func buildDailyLevel(date: Date, screenWidth: Double, screenHeight: Double) -> [Brick] {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        var rng = SeededGenerator(seed: UInt64(year * 1000 + month * 100 + day))

        var bricks: [Brick] = []
        let rows = 5
        let cols = 7
        let gap = 6.0
        let bw = (screenWidth - 36.0 - gap * Double(cols - 1)) / Double(cols)
        let totalW = Double(cols) * bw + gap * Double(cols - 1)
        let startX = (screenWidth - totalW) / 2.0
        let bh = 22.0

        for r in 0..<rows {
            for c in 0..<cols {
                if rng.nextDouble() > 0.18 {
                    let isSteel = (r == 1 && (c == 2 || c == 4))
                    let color = icePalette[rng.nextInt(icePalette.count)]
                    let hp = isSteel ? 999 : (rng.nextBool() ? 2 : 1)
                    bricks.append(
                        Brick(
                            x: startX + Double(c) * (bw + gap),
                            y: baseTopMargin + Double(r) * (bh + gap),
                            width: bw,
                            height: bh,
                            hp: hp,
                            maxHp: isSteel ? 999 : 2,
                            isSteel: isSteel,
                            color: isSteel ? Color(hex: 0xFFCFD8DC) : color,
                            points: 25
                        )
                    )
                }
            }
        }
        return bricks
    }

    static func buildShapesLevel(level: Int, screenWidth: Double, screenHeight: Double) -> [Brick] {
        var bricks: [Brick] = []
        let shapes = [shapeHeart, shapeSword, shapeSmiley, shapeDiamond]
        let matrix = shapes[(level - 1) % shapes.count]
        
        let rows = matrix.count
        let cols = matrix[0].count
        let gap = 6.0
        let bw = (screenWidth - 40.0 - gap * Double(cols - 1)) / Double(cols)
        let totalW = Double(cols) * bw + gap * Double(cols - 1)
        let startX = (screenWidth - totalW) / 2.0
        let bh = 22.0

        for r in 0..<rows {
            for c in 0..<cols {
                if matrix[r][c] == 1 {
                    let color = candyPalette[(r + c) % candyPalette.count]
                    bricks.append(
                        Brick(
                            x: startX + Double(c) * (bw + gap),
                            y: baseTopMargin + Double(r) * (bh + gap),
                            width: bw,
                            height: bh,
                            hp: 1,
                            maxHp: 1,
                            minX: 16.0,
                            maxX: screenWidth - 16.0,
                            color: color,
                            points: 20
                        )
                    )
                }
            }
        }
        return bricks
    }
}

/// Deterministic pseudo-random generator for Daily Level layout consistency.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    mutating func nextBool() -> Bool {
        (nextUInt64() & 1) == 1
    }
}
