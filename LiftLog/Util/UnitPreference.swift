import Foundation
import SwiftUI

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lbs
    var id: String { rawValue }
    var label: String { rawValue }
}

final class UnitPreference: ObservableObject {
    @AppStorage("weightUnit") private var storedUnit: String = WeightUnit.lbs.rawValue

    var unit: WeightUnit {
        get { WeightUnit(rawValue: storedUnit) ?? .lbs }
        set { storedUnit = newValue.rawValue; objectWillChange.send() }
    }
}

extension Double {
    func formattedWeight(unit: WeightUnit) -> String {
        let rounded = (self * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded)) \(unit.label)"
        }
        return String(format: "%.1f %@", rounded, unit.label)
    }
}
