import Foundation

struct RoutineTemplate {
    let id: String
    let name: String
    let subtitle: String
    let days: [TemplateDay]

    struct TemplateDay {
        let name: String
        let exercises: [String]
    }

    static let fiveDaySplit = RoutineTemplate(
        id: "five-day-split",
        name: "5-Day Split",
        subtitle: "Chest · Back · Legs · Shoulders · Mixed",
        days: [
            .init(name: "Day 1", exercises: [
                "Inclined Chest Machine Press",
                "Pec Dec",
                "Shoulder Machine Press",
                "Machine Lateral Raises",
                "Inclined DB Curls"
            ]),
            .init(name: "Day 2", exercises: [
                "Normal Grip Lat Pull Down",
                "Seated Wide Grip Cable Rows",
                "Cable Triceps Pushdown",
                "Dumbell Shrugs",
                "Crunches"
            ]),
            .init(name: "Day 3", exercises: [
                "Goblet Squats",
                "Lying Leg Curls",
                "Leg Extension Machine",
                "Preacher Curls Machine",
                "Crunches"
            ]),
            .init(name: "Day 4", exercises: [
                "Shoulder Machine Press",
                "Machine Lateral Raises",
                "Chest Press Machine",
                "Pec Dec",
                "Overhead Extensions with Rope"
            ]),
            .init(name: "Day 5", exercises: [
                "Goblet Squats",
                "Normal Grip Lat Pull Down",
                "Lying Leg Curls",
                "Seated Wide Grip Cable Rows",
                "Leg Extension Machine"
            ])
        ]
    )
}
