import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    let exerciseName: String

    @Query private var logs: [LoggedExercise]

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        let name = exerciseName
        self._logs = Query(
            filter: #Predicate<LoggedExercise> { $0.exerciseName == name && $0.isCompleted }
        )
    }

    private var sortedLogs: [LoggedExercise] {
        logs
            .filter { $0.session?.date != nil && !$0.orderedSets.isEmpty }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            if sortedLogs.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Log some sets and they’ll appear here.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sortedLogs) { log in
                            SessionLogCard(log: log, unit: unitPref.unit)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SessionLogCard: View {
    let log: LoggedExercise
    let unit: WeightUnit

    private var date: Date { log.session?.date ?? .now }
    private var dayName: String { log.session?.dayName ?? "" }
    private var routineName: String { log.session?.routineName ?? "" }

    private var topE1RM: Double {
        log.orderedSets.map(\.estimatedOneRepMax).max() ?? 0
    }

    private var totalVolume: Double {
        log.orderedSets.map(\.volume).reduce(0, +)
    }

    private var totalReps: Int {
        log.orderedSets.map(\.reps).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                    HStack(spacing: 6) {
                        if !dayName.isEmpty {
                            Text(dayName)
                        }
                        if !dayName.isEmpty && !routineName.isEmpty {
                            Text("•").foregroundStyle(.tertiary)
                        }
                        if !routineName.isEmpty {
                            Text(routineName)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(log.orderedSets) { entry in
                    SetLine(entry: entry, unit: unit)
                }
            }

            Divider()

            HStack(spacing: 16) {
                MetaCell(label: "TOP e1RM", value: topE1RM.formattedWeight(unit: unit))
                MetaCell(label: "VOLUME", value: totalVolume.formattedWeight(unit: unit))
                MetaCell(label: "TOTAL REPS", value: "\(totalReps)")
            }
        }
        .card()
    }
}

private struct SetLine: View {
    let entry: SetEntry
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.order + 1)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Theme.accentSoft)
                .foregroundStyle(Theme.accent)
                .clipShape(Circle())
            Text(entry.weight.formattedWeight(unit: unit))
                .font(.callout.monospacedDigit())
            Text("×").foregroundStyle(.secondary)
            Text("\(entry.reps) reps")
                .font(.callout.monospacedDigit())
            Spacer()
            Text("e1RM \(entry.estimatedOneRepMax.formattedWeight(unit: unit))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetaCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2.bold())
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
