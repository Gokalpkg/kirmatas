import Foundation

func generateRandomSymmetricShape(level: Int) -> [[Int]] {
    let rows = Int.random(in: 4...7)
    let cols = 7 // Keep it odd for symmetry
    var matrix = Array(repeating: Array(repeating: 0, count: cols), count: rows)
    
    for r in 0..<rows {
        for c in 0...(cols/2) {
            // Random chance based on level or just random
            if Double.random(in: 0...1) > 0.3 {
                matrix[r][c] = 1
                matrix[r][cols - 1 - c] = 1 // Mirror
            }
        }
    }
    return matrix
}
