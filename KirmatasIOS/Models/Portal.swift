import Foundation
import SwiftUI

final class Portal {
    var x: Double
    var y: Double
    var radius: Double
    var color: Color
    var rotation: Double = 0
    var isBlue: Bool
    weak var linkedPortal: Portal?

    init(x: Double, y: Double, radius: Double, color: Color, isBlue: Bool) {
        self.x = x
        self.y = y
        self.radius = radius
        self.color = color
        self.isBlue = isBlue
    }

    func update(dt: Double) {
        rotation += 3.0 * dt
    }
}

enum PortalCatalog {
    /// Same density as GitHub main: 83 of the first 238 classic levels host a portal pair.
    static let levels: Set<Int> = {
        var rng = SeededRNG(seed: 2026)
        var all = Array(1...238)
        var i = all.count - 1
        while i > 0 {
            let j = rng.nextInt(upperBound: i + 1)
            all.swapAt(i, j)
            i -= 1
        }
        return Set(all.prefix(83))
    }()
}

struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x5A17 : seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int(state % UInt64(upperBound))
    }

    mutating func nextDouble() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
