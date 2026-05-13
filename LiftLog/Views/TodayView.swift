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
                .foregroundStyle(.secondary)
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
    @Query private var allSessions: [WorkoutSession]

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

                Button {
                    showingFinishConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Text(session == nil ? "Skip day & advance" : "End day & advance")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.primary)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                }
                .padding(.top, 8)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            restoreInProgressSession()
        }
        .onChange(of: day.id) { _, _ in
            resetSessionForDayChange()
            restoreInProgressSession()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            }
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

    private func restoreInProgressSession() {
        guard session == nil else { return }
        let cutoff = Calendar.current.date(byAdding: .hour, value: -18, to: .now) ?? .distantPast
        let candidate = allSessions
            .filter { s in
                s.isCompleted == false
                    && s.date >= cutoff
                    && s.dayName == day.name
                    && s.routineName == routine.name
            }
            .max { $0.date < $1.date }
        session = candidate
    }

    private func resetSessionForDayChange() {
        if let s = session {
            let hasRealWork = s.loggedExercises.contains { log in
                log.sets.contains { $0.weight > 0 && $0.reps > 0 }
            }
            if hasRealWork {
                s.isCompleted = true
            } else {
                context.delete(s)
            }
            do { try context.save() } catch {
                print("[LiftLog] resetSession cleanup failed: \(error)")
            }
        }
        session = nil
    }

    private func finishSession(advance: Bool) {
        if let s = session {
            let hasAnyLoggedWork = s.loggedExercises.contains { log in
                log.sets.contains { $0.weight > 0 && $0.reps > 0 }
            }
            if hasAnyLoggedWork {
                s.isCompleted = true
            } else {
                context.delete(s)
            }
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
                .foregroundStyle(.secondary)

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
        let key = exercise.name.normalizedExerciseKey
        return allLogs.filter { log in
            log.exerciseName.normalizedExerciseKey == key
                && log.session?.isCompleted == true
                && log.session !== session
                && log.orderedSets.contains { $0.weight > 0 && $0.reps > 0 }
        }
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
        if let log = currentLog, log.isCompleted {
            collapsedView(for: log)
        } else if currentLog == nil {
            idleRow
        } else {
            expandedView
        }
    }

    private var idleRow: some View {
        HStack(spacing: 12) {
            Text(exercise.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            NavigationLink {
                ExerciseHistoryView(exerciseName: exercise.name)
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
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
        .contentShape(Rectangle())
        .onTapGesture {
            startLogging()
        }
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
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

                if currentLog != nil {
                    Image(systemName: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let log = currentLog {
                    log.isCompleted = true
                    save("collapseExercise")
                }
            }

            PreviousSessionStrip(previous: previousSession, unit: unitPref.unit)

            if let log = currentLog {
                VStack(spacing: 6) {
                    ForEach(log.orderedSets) { entry in
                        SwipeableRow(onDelete: { delete(entry, from: log) }) {
                            SetRowView(entry: entry)
                        }
                    }
                }

                Button {
                    addSet(to: log)
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .card()
    }

    private func collapsedView(for log: LoggedExercise) -> some View {
        let useful = log.orderedSets.filter { $0.weight > 0 && $0.reps > 0 }
        let topSet = useful.max { $0.weight < $1.weight }
        return Button {
            log.isCompleted = false
            save("expandExercise")
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
                Image(systemName: "chevron.down")
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

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.order + 1)")
                .font(.callout.bold())
                .frame(width: 26, height: 26)
                .background(Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(.secondary)
                .clipShape(Circle())

            NumericField(value: $entry.weight, placeholder: "0", suffix: unitPref.unit.label)
            Text("×").foregroundStyle(.secondary)
            NumericIntField(value: $entry.reps, placeholder: "0")

            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
}

private struct SwipeableRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var armed: Bool = false

    private let actionWidth: CGFloat = 72
    private let triggerThreshold: CGFloat = 90

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background — visible only when swiped open.
            Button(action: commitDelete) {
                Image(systemName: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: actionWidth, height: 40)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(offset < -8 ? 1 : 0)

            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 25)
                        .onChanged { value in
                            // Only react to clear horizontal swipes.
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            if value.translation.width < 0 {
                                offset = max(-actionWidth - 20, value.translation.width)
                            } else if armed {
                                offset = min(0, -actionWidth + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                if value.translation.width < -triggerThreshold {
                                    commitDelete()
                                } else if value.translation.width < -actionWidth/2 {
                                    offset = -actionWidth - 4
                                    armed = true
                                } else {
                                    offset = 0
                                    armed = false
                                }
                            }
                        }
                )
        }
    }

    private func commitDelete() {
        withAnimation(.easeInOut(duration: 0.22)) {
            offset = -600
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDelete()
        }
    }
}

private struct NumericField: View {
    @Binding var value: Double
    let placeholder: String
    let suffix: String

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($focused)
                .onAppear { syncFromValue() }
                .onChange(of: text) { _, newText in
                    let cleaned = newText.replacingOccurrences(of: ",", with: ".")
                    value = Double(cleaned) ?? 0
                }
                .onChange(of: value) { _, _ in
                    if !focused { syncFromValue() }
                }
            Text(suffix)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func syncFromValue() {
        if value == 0 {
            text = ""
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            text = "\(Int(value))"
        } else {
            text = String(format: "%g", value)
        }
    }
}

private struct NumericIntField: View {
    @Binding var value: Int
    let placeholder: String

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(minWidth: 52)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($focused)
            .onAppear { syncFromValue() }
            .onChange(of: text) { _, newText in
                value = Int(newText) ?? 0
            }
            .onChange(of: value) { _, _ in
                if !focused { syncFromValue() }
            }
    }

    private func syncFromValue() {
        text = value == 0 ? "" : "\(value)"
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
