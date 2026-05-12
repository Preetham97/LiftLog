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
            VStack(spacing: 10) {
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
                        HStack(spacing: 6) {
                            Text("Finish day & advance")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Theme.accent)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .confirmationDialog(
            "Advance to \(nextDayName)?",
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Yes — advance to \(nextDayName)") {
                finishSession(advance: true)
            }
            Button("Stay on \(day.name)") {
                finishSession(advance: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your sets are already saved. This only moves the routine cycle forward — you can adjust the next day later in the Routines tab.")
        }
    }

    private func finishSession(advance: Bool) {
        guard let s = session else { return }
        let hasAnyLoggedWork = s.loggedExercises.contains { log in
            log.sets.contains { $0.weight > 0 && $0.reps > 0 }
        }
        if !hasAnyLoggedWork {
            context.delete(s)
        }
        if advance {
            routine.advanceDay()
        }
        do {
            try context.save()
        } catch {
            print("[LiftLog] save failed in finishSession: \(error)")
        }
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

    @Query private var allLogs: [LoggedExercise]

    init(exercise: Exercise, session: Binding<WorkoutSession?>, routine: Routine, day: RoutineDay) {
        self.exercise = exercise
        self._session = session
        self.routine = routine
        self.day = day
    }

    private var previousLogs: [LoggedExercise] {
        allLogs.filter { $0.exerciseName == exercise.name && $0.isCompleted }
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

    @State private var manuallyExpanded: Bool = false

    var body: some View {
        if let log = currentLog, log.isCompleted, !manuallyExpanded {
            collapsedView(for: log)
        } else {
            expandedView
        }
    }

    private var hasUsefulSets: Bool {
        currentLog?.orderedSets.contains { $0.weight > 0 && $0.reps > 0 } ?? false
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                if let log = currentLog, log.isCompleted {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 8, height: 8)
                }
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ExerciseHistoryView(exerciseName: exercise.name)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if let log = currentLog, log.isCompleted, manuallyExpanded {
                    Button {
                        manuallyExpanded = false
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            PreviousSessionStrip(previous: previousSession, unit: unitPref.unit)

            if let log = currentLog {
                VStack(spacing: 6) {
                    ForEach(log.orderedSets) { entry in
                        SetRowView(
                            entry: entry,
                            onToggleDone: { handleToggleDone(entry, in: log) },
                            onDelete: { delete(entry, from: log) }
                        )
                    }
                }

                HStack {
                    Button {
                        addSet(to: log)
                    } label: {
                        Label("Add set", systemImage: "plus")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if !log.isCompleted {
                        Button {
                            finishExercise(log)
                            manuallyExpanded = false
                        } label: {
                            HStack(spacing: 4) {
                                Text("Mark done")
                                Image(systemName: "arrow.right")
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(hasUsefulSets ? Theme.accent : Color.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasUsefulSets)
                    }
                }
                .padding(.top, 4)
            } else {
                Button {
                    startLogging()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Start logging")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accentSoft)
                    .foregroundStyle(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                }
            }
        }
        .card()
    }

    private func collapsedView(for log: LoggedExercise) -> some View {
        let useful = log.orderedSets.filter { $0.weight > 0 && $0.reps > 0 }
        let topSet = useful.max { $0.weight < $1.weight }
        return Button {
            manuallyExpanded = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text("\(useful.count) set\(useful.count == 1 ? "" : "s")")
                        if let top = topSet {
                            Text("•").foregroundStyle(.tertiary)
                            Text("top \(top.weight.formattedWeight(unit: unitPref.unit)) × \(top.reps)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func startLogging() {
        let s = session ?? {
            let new = WorkoutSession(date: .now, dayName: day.name, routineName: routine.name)
            context.insert(new)
            session = new
            return new
        }()
        let log = LoggedExercise(exerciseName: exercise.name, order: exercise.order)
        context.insert(log)
        log.session = s
        s.loggedExercises.append(log)
        addSet(to: log)
        save("startLogging")
    }

    private func addSet(to log: LoggedExercise) {
        let order = (log.orderedSets.last?.order ?? -1) + 1
        let entry = SetEntry(order: order, weight: 0, reps: 0)
        context.insert(entry)
        entry.loggedExercise = log
        log.sets.append(entry)
        save("addSet")
    }

    private func delete(_ entry: SetEntry, from log: LoggedExercise) {
        context.delete(entry)
        save("deleteSet")
    }

    private func finishExercise(_ log: LoggedExercise) {
        if let last = log.orderedSets.last,
           last.weight == 0, last.reps == 0, !last.isCompleted {
            context.delete(last)
        }
        for s in log.orderedSets where !s.isCompleted && s.weight > 0 && s.reps > 0 {
            s.isCompleted = true
            s.completedAt = .now
        }
        log.isCompleted = true
        save("finishExercise")
    }

    private func handleToggleDone(_ entry: SetEntry, in log: LoggedExercise) {
        entry.isCompleted.toggle()
        if entry.isCompleted {
            entry.completedAt = .now
            let isLast = log.orderedSets.last?.id == entry.id
            if isLast {
                addSet(to: log)
            }
        }
        save("toggleDone")
    }

    private func save(_ source: String) {
        do {
            try context.save()
        } catch {
            print("[LiftLog] save failed in \(source): \(error)")
        }
    }
}

private struct PreviousSessionStrip: View {
    let previous: LoggedExercise?
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(previous == nil ? "First time logging this lift" : "Last \(previous?.session?.date.formatted(.relative(presentation: .named)) ?? "")")
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)

            if let prev = previous, !prev.orderedSets.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(prev.orderedSets) { s in
                        Text("\(formatWeight(s.weight, unit: unit))×\(s.reps)")
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let onToggleDone: () -> Void
    let onDelete: () -> Void

    private var canMarkDone: Bool {
        entry.weight > 0 && entry.reps > 0
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.order + 1)")
                .font(.callout.bold())
                .frame(width: 26, height: 26)
                .background(Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(entry.isCompleted ? Theme.accent : .secondary)
                .clipShape(Circle())

            NumericField(value: $entry.weight, placeholder: "0", suffix: unitPref.unit.label)
            Text("×").foregroundStyle(.secondary)
            NumericIntField(value: $entry.reps, placeholder: "0")

            Spacer(minLength: 4)

            Button(action: onToggleDone) {
                Circle()
                    .strokeBorder(
                        entry.isCompleted ? Color.clear : Color.secondary.opacity(0.4),
                        lineWidth: 1.5
                    )
                    .background(
                        Circle().fill(entry.isCompleted ? Theme.accent : Color.clear)
                    )
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(!canMarkDone && !entry.isCompleted)
            .opacity((!canMarkDone && !entry.isCompleted) ? 0.4 : 1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(entry.isCompleted ? Theme.accentSoft : Color.clear)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete set", systemImage: "trash")
            }
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
