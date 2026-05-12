import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Routine.self,
            RoutineDay.self,
            Exercise.self,
            WorkoutSession.self,
            LoggedExercise.self,
            SetEntry.self
        ])
    }
}
