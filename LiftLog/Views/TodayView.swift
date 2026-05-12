import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    var activeRoutine: Routine? {
        routines.first(where: \.isActive) ?? routines.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                Group {
                    if routines.isEmpty {
                        EmptyTodayState()
                    } else if let routine = activeRoutine, let day = routine.nextDay {
                        TodaySessionView(routine: routine, day: day)
                    } else if let routine = activeRoutine {
                        ContentUnavailableView(
                            "No days in this routine",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Add at least one day to “\(routine.name)” in the Routines tab.")
                        )
                    }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct EmptyTodayState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 4)
            Text("Ready to lift?")
                .font(.title2.bold())
            Text("Create a routine in the Routines tab to start logging sessions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
    }
}

struct TodaySessionView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var unitPref: UnitPreference

    let routine: Routine
    let day: RoutineDay

    @State private var session: WorkoutSession?
    @State private var showingFinishConfirm = false

    private var nextDayName: String {
        let ordered = routine.orderedDays
        guard !ordered.isEmpty else { return "—" }
        let next = (routine.currentDayIndex + 1) % ordered.count
        return ordered[next].name
    }

    private var totalSets: Int {
        session?.loggedExercises.reduce(0) { $0 + $1.sets.count } ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeroHeader(routine: routine, day: day, totalSets: totalSets)

                ForEach(day.orderedExercises) { exercise in
                    ExerciseLogCard(
                        exercise: exercise,
                        session: $session,
                        routine: routine,
                        day: day
                    )
                }

                if session != nil {
                    Button {
                        showingFinishConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish session")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .confirmationDialog(
            "Finish \(day.name)?",
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish & advance to \(nextDayName)") {
                finishSession(advance: true)
            }
            Button("Save without advancing") {
                finishSession(advance: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Advancing moves your routine to the next day. You can adjust this later in the Routines tab.")
        }
    }

    private func finishSession(advance: Bool) {
        guard let s = session else { return }
        if s.loggedExercises.isEmpty {
            context.delete(s)
        }
        if advance {
            routine.advanceDay()
        }
        try? context.save()
        session = nil
    }
}

private struct HeroHeader: View {
    let routine: Routine
    let day: RoutineDay
    let totalSets: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(routine.name.uppercased())
                .font(.caption.bold())
                .tracking(1.2)
                .foregroundStyle(Theme.accent)

            Text(day.name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                Text("•").foregroundStyle(.tertiary)
                Text("\(day.exercises.count) lift\(day.exercises.count == 1 ? "" : "s")")
                if totalSets > 0 {
                    Text("•").foregroundStyle(.tertiary)
                    Text("\(totalSets) set\(totalSets == 1 ? "" : "s") logged")
                        .foregroundStyle(Theme.accent)
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

private struct ExerciseLogCard: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var unitPref: UnitPreference

    let exercise: Exercise
    @Binding var session: WorkoutSession?
    let routine: Routine
    let day: RoutineDay

    @Query private var previousLogs: [LoggedExercise]

    init(exercise: Exercise, session: Binding<WorkoutSession?>, routine: Routine, day: RoutineDay) {
        self.exercise = exercise
        self._session = session
        self.routine = routine
        self.day = day
        let name = exercise.name
        self._previousLogs = Query(
            filter: #Predicate<LoggedExercise> { $0.exerciseName == name },
            sort: [SortDescriptor(\LoggedExercise.order)]
        )
    }

    private var previousSession: LoggedExercise? {
        previousLogs
            .compactMap { log -> (LoggedExercise, Date)? in
                guard let date = log.session?.date else { return nil }
                return (log, date)
            }
            .sorted { $0.1 > $1.1 }
            .first?.0
    }

    private var currentLog: LoggedExercise? {
        session?.loggedExercises.first { $0.exerciseName == exercise.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                if let log = currentLog {
                    PillLabel(text: "\(log.sets.count) SET\(log.sets.count == 1 ? "" : "S")")
                }
                NavigationLink {
                    ExerciseHistoryView(exerciseName: exercise.name)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            PreviousSessionStrip(previous: previousSession, unit: unitPref.unit)

            if let log = currentLog {
                VStack(spacing: 8) {
                    ForEach(log.orderedSets) { entry in
                        SetRowView(entry: entry, onDelete: { delete(entry, from: log) })
                    }
                }
                Button {
                    addSet(to: log)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add set")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accentSoft)
                    .foregroundStyle(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                }
            } else {
                Button {
                    startLogging()
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Start logging")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                }
            }
        }
        .card()
    }

    private func startLogging() {
        let s = session ?? {
            let new = WorkoutSession(date: .now, dayName: day.name, routineName: routine.name)
            context.insert(new)
            session = new
            return new
        }()
        let log = LoggedExercise(exerciseName: exercise.name, order: exercise.order)
        log.session = s
        context.insert(log)
        addSet(to: log)
    }

    private func addSet(to log: LoggedExercise) {
        let order = (log.orderedSets.last?.order ?? -1) + 1
        let entry = SetEntry(order: order, weight: 0, reps: 0)
        entry.loggedExercise = log
        context.insert(entry)
    }

    private func delete(_ entry: SetEntry, from log: LoggedExercise) {
        context.delete(entry)
        try? context.save()
    }
}

private struct PreviousSessionStrip: View {
    let previous: LoggedExercise?
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                Text(previous == nil ? "First time logging this lift" : "Last session • \(previous?.session?.date.formatted(.relative(presentation: .named)) ?? "")")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            if let prev = previous, !prev.orderedSets.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(prev.orderedSets) { s in
                        Text("\(formatWeight(s.weight, unit: unit)) × \(s.reps)")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func formatWeight(_ w: Double, unit: WeightUnit) -> String {
        if w.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(w))"
        }
        return String(format: "%.1f", w)
    }
}

private struct SetRowView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    @Bindable var entry: SetEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.order + 1)")
                .font(.callout.bold())
                .frame(width: 28, height: 28)
                .background(Theme.accentSoft)
                .foregroundStyle(Theme.accent)
                .clipShape(Circle())

            NumericField(value: $entry.weight, placeholder: "0", suffix: unitPref.unit.label)
            Text("×").foregroundStyle(.secondary)
            NumericIntField(value: $entry.reps, placeholder: "0")

            Spacer(minLength: 4)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NumericField: View {
    @Binding var value: Double
    let placeholder: String
    let suffix: String

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(suffix)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NumericIntField: View {
    @Binding var value: Int
    let placeholder: String

    var body: some View {
        TextField(placeholder, value: $value, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(minWidth: 52)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
