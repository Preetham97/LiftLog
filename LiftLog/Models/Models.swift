import Foundation
import SwiftData

@Model
final class Routine {
    var name: String = ""
    var createdAt: Date = Date.now
    var currentDayIndex: Int = 0
    var isActive: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \RoutineDay.routine)
    var days: [RoutineDay] = []

    init(name: String, createdAt: Date = .now, currentDayIndex: Int = 0, isActive: Bool = false) {
        self.name = name
        self.createdAt = createdAt
        self.currentDayIndex = currentDayIndex
        self.isActive = isActive
    }

    var orderedDays: [RoutineDay] {
        days.sorted { $0.order < $1.order }
    }

    var nextDay: RoutineDay? {
        let ordered = orderedDays
        guard !ordered.isEmpty else { return nil }
        let idx = ((currentDayIndex % ordered.count) + ordered.count) % ordered.count
        return ordered[idx]
    }

    func advanceDay() {
        let count = days.count
        guard count > 0 else { return }
        currentDayIndex = (currentDayIndex + 1) % count
    }
}

@Model
final class RoutineDay {
    var name: String = ""
    var order: Int = 0
    var routine: Routine?
    @Relationship(deleteRule: .cascade, inverse: \Exercise.day)
    var exercises: [Exercise] = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var orderedExercises: [Exercise] {
        exercises.sorted { $0.order < $1.order }
    }
}

@Model
final class Exercise {
    var name: String = ""
    var muscleGroup: String = ""
    var order: Int = 0
    var notes: String = ""
    var isBodyweight: Bool = false
    var day: RoutineDay?

    init(name: String, muscleGroup: String = "", order: Int = 0, notes: String = "", isBodyweight: Bool = false) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.order = order
        self.notes = notes
        self.isBodyweight = isBodyweight
    }
}

@Model
final class WorkoutSession {
    var date: Date = Date.now
    var dayName: String = ""
    var routineName: String = ""
    var isCompleted: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session)
    var loggedExercises: [LoggedExercise] = []

    init(date: Date = .now, dayName: String, routineName: String, isCompleted: Bool = false) {
        self.date = date
        self.dayName = dayName
        self.routineName = routineName
        self.isCompleted = isCompleted
    }
}

@Model
final class LoggedExercise {
    var exerciseName: String = ""
    var order: Int = 0
    var isCompleted: Bool = false
    var isBodyweight: Bool = false
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.loggedExercise)
    var sets: [SetEntry] = []

    init(exerciseName: String, order: Int, isCompleted: Bool = false, isBodyweight: Bool = false) {
        self.exerciseName = exerciseName
        self.order = order
        self.isCompleted = isCompleted
        self.isBodyweight = isBodyweight
    }

    var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }

    /// True if this lift is bodyweight either by explicit flag or by data shape
    /// (every valid set has zero weight). Lets old logs without the flag still
    /// display as bodyweight when that's clearly what they are.
    var effectiveIsBodyweight: Bool {
        if isBodyweight { return true }
        let withReps = orderedSets.filter { $0.reps > 0 }
        return !withReps.isEmpty && withReps.allSatisfy { $0.weight == 0 }
    }

    /// A set "counts" as logged work if it satisfies the lift type's minimum:
    /// reps for bodyweight, weight × reps for weighted.
    func setIsValid(_ entry: SetEntry) -> Bool {
        if effectiveIsBodyweight { return entry.reps > 0 }
        return entry.weight > 0 && entry.reps > 0
    }

    var hasAnyValidSet: Bool {
        sets.contains { setIsValid($0) }
    }

    var validSets: [SetEntry] {
        orderedSets.filter { setIsValid($0) }
    }
}

@Model
final class SetEntry {
    var order: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var rpe: Double?
    var isCompleted: Bool = false
    var completedAt: Date = Date.now
    var loggedExercise: LoggedExercise?

    init(order: Int, weight: Double, reps: Int, rpe: Double? = nil, isCompleted: Bool = false, completedAt: Date = .now) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    var estimatedOneRepMax: Double {
        guard reps > 0, weight > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    var volume: Double {
        weight * Double(reps)
    }
}
