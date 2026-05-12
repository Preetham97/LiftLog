import Foundation
import SwiftUI

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lbs
    var id: String { rawValue }
    var label: String { rawValue }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "iphone"
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

final class UnitPreference: ObservableObject {
    @AppStorage("weightUnit") private var storedUnit: String = WeightUnit.lbs.rawValue
    @AppStorage("appTheme") private var storedTheme: String = AppTheme.system.rawValue

    var unit: WeightUnit {
        get { WeightUnit(rawValue: storedUnit) ?? .lbs }
        set { storedUnit = newValue.rawValue; objectWillChange.send() }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: storedTheme) ?? .system }
        set { storedTheme = newValue.rawValue; objectWillChange.send() }
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
