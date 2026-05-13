import Foundation

struct RoutineTemplate {
    let id: String
    let name: String
    let subtitle: String
    let days: [TemplateDay]

    struct TemplateDay {
        let name: String
        let exercises: [TemplateExercise]
    }

    struct TemplateExercise {
        let name: String
        let isBodyweight: Bool

        init(_ name: String, bodyweight: Bool = false) {
            self.name = name
            self.isBodyweight = bodyweight
        }
    }

    static let fiveDaySplit = RoutineTemplate(
        id: "five-day-split",
        name: "5-Day Split",
        subtitle: "Chest · Back · Legs · Shoulders · Mixed",
        days: [
            .init(name: "Day 1", exercises: [
                .init("Inclined Chest Machine Press"),
                .init("Pec Dec"),
                .init("Shoulder Machine Press"),
                .init("Machine Lateral Raises"),
                .init("Inclined DB Curls")
            ]),
            .init(name: "Day 2", exercises: [
                .init("Normal Grip Lat Pull Down"),
                .init("Seated Wide Grip Cable Rows"),
                .init("Cable Triceps Pushdown"),
                .init("Dumbell Shrugs"),
                .init("Crunches", bodyweight: true)
            ]),
            .init(name: "Day 3", exercises: [
                .init("Goblet Squats"),
                .init("Lying Leg Curls"),
                .init("Leg Extension Machine"),
                .init("Preacher Curls Machine"),
                .init("Crunches", bodyweight: true)
            ]),
            .init(name: "Day 4", exercises: [
                .init("Shoulder Machine Press"),
                .init("Machine Lateral Raises"),
                .init("Chest Press Machine"),
                .init("Pec Dec"),
                .init("Overhead Extensions with Rope")
            ]),
            .init(name: "Day 5", exercises: [
                .init("Goblet Squats"),
                .init("Normal Grip Lat Pull Down"),
                .init("Lying Leg Curls"),
                .init("Seated Wide Grip Cable Rows"),
                .init("Leg Extension Machine")
            ])
        ]
    )
}
