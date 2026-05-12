import Foundation

/// Canonical comparison key for exercise names.
/// "Bench Press", "bench press", "  Bench   Press " all collapse to "bench press".
extension String {
    var normalizedExerciseKey: String {
        self
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}
