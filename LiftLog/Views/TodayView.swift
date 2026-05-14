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

enum SetField: Hashable {
    case weight(PersistentIdentifier)
    case reps(PersistentIdentifier)
}

struct TodaySessionView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var unitPref: UnitPreference
    @Query private var allSessions: [WorkoutSession]

    let routine: Routine
    let day: RoutineDay

    @State private var session: WorkoutSession?
    @State private var showingFinishConfirm = false
    @State private var showingAddExercise = false
    @State private var skippedExpanded = true
    @State private var skippedPendingDelete: (key: String, name: String)?
    @FocusState private var focusedField: SetField?

    struct DisplayedExerciseItem: Identifiable {
        let id: String  // normalized key
        let name: String
        let isBodyweight: Bool
        let order: Int
    }

    private var visibleExercises: [DisplayedExerciseItem] {
        let skipped = Set(session?.skippedExerciseKeys ?? [])
        var seenKeys = Set<String>()
        var items: [DisplayedExerciseItem] = []

        for ex in day.orderedExercises {
            let key = ex.name.normalizedExerciseKey
            if skipped.contains(key) { continue }
            seenKeys.insert(key)
            items.append(.init(id: key, name: ex.name, isBodyweight: ex.isBodyweight, order: ex.order))
        }

        if let s = session {
            let orderedLogs = s.loggedExercises.sorted { $0.order < $1.order }
            for log in orderedLogs {
                let key = log.exerciseName.normalizedExerciseKey
                if seenKeys.contains(key) { continue }
                if skipped.contains(key) { continue }
                seenKeys.insert(key)
                items.append(.init(
                    id: key,
                    name: log.exerciseName,
                    isBodyweight: log.isBodyweight,
                    order: log.order
                ))
            }
        }

        return items
    }

    /// Exercises the user swiped to skip for this session, paired with the
    /// original template name when available so we can show their full label.
    private var skippedItems: [(key: String, name: String)] {
        guard let s = session else { return [] }
        let templateByKey = Dictionary(
            uniqueKeysWithValues: day.orderedExercises.map { ($0.name.normalizedExerciseKey, $0.name) }
        )
        return s.skippedExerciseKeys.map { key in
            (key, templateByKey[key] ?? key.capitalized)
        }
    }

    private func restoreSkipped(key: String) {
        guard let s = session else { return }
        // Re-assign the whole array so SwiftData's change tracker fires
        // (mutating in place with .removeAll doesn't trigger the observer).
        s.skippedExerciseKeys = s.skippedExerciseKeys.filter { $0 != key }
        do { try context.save() } catch {
            print("[LiftLog] restoreSkipped failed: \(error)")
        }
    }

    /// Permanently removes a skipped exercise. If it's part of the routine
    /// template, the Exercise is deleted from the day so it won't show up
    /// in future sessions either. For one-offs (no template), this just
    /// clears the skip marker. Either way the entry vanishes from the
    /// "Skipped today" list.
    private func deleteSkipped(key: String) {
        if let template = day.orderedExercises.first(where: { $0.name.normalizedExerciseKey == key }) {
            context.delete(template)
        }
        if let s = session {
            s.skippedExerciseKeys = s.skippedExerciseKeys.filter { $0 != key }
        }
        do { try context.save() } catch {
            print("[LiftLog] deleteSkipped failed: \(error)")
        }
    }

    /// Reorders the visible exercises and persists the new `order` on the
    /// underlying Exercise template and LoggedExercise (if one exists).
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var items = visibleExercises
        items.move(fromOffsets: source, toOffset: destination)
        for (idx, item) in items.enumerated() {
            if let ex = day.exercises.first(where: { $0.name.normalizedExerciseKey == item.id }) {
                ex.order = idx
            }
            if let log = session?.loggedExercises.first(where: { $0.exerciseName.normalizedExerciseKey == item.id }) {
                log.order = idx
            }
        }
        do { try context.save() } catch {
            print("[LiftLog] moveExercises failed: \(error)")
        }
    }

    private func skip(_ item: DisplayedExerciseItem) {
        let s = session ?? {
            let new = WorkoutSession(date: .now, dayName: day.name, routineName: routine.name)
            context.insert(new)
            session = new
            return new
        }()
        // Remove any in-progress log for this exercise.
        if let existing = s.loggedExercises.first(where: { $0.exerciseName.normalizedExerciseKey == item.id }) {
            context.delete(existing)
        }
        if !s.skippedExerciseKeys.contains(item.id) {
            s.skippedExerciseKeys = s.skippedExerciseKeys + [item.id]
        }
        do { try context.save() } catch {
            print("[LiftLog] skip exercise failed: \(error)")
        }
    }

    private func addOneOff(name: String, isBodyweight: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let key = trimmed.normalizedExerciseKey

        let s = session ?? {
            let new = WorkoutSession(date: .now, dayName: day.name, routineName: routine.name)
            context.insert(new)
            session = new
            return new
        }()

        // If it's currently in the skipped list, un-skip it.
        s.skippedExerciseKeys = s.skippedExerciseKeys.filter { $0 != key }

        // If a log for this exercise already exists in the session, do nothing.
        let already = s.loggedExercises.contains { $0.exerciseName.normalizedExerciseKey == key }
        guard !already else {
            do { try context.save() } catch { print("[LiftLog] addOneOff save failed: \(error)") }
            return
        }

        // Order goes at the end of any existing logs / template order.
        let templateMax = day.exercises.map(\.order).max() ?? -1
        let logMax = s.loggedExercises.map(\.order).max() ?? -1
        let nextOrder = max(templateMax, logMax) + 1

        let log = LoggedExercise(
            exerciseName: trimmed,
            order: nextOrder,
            isBodyweight: isBodyweight
        )
        context.insert(log)
        log.session = s
        s.loggedExercises.append(log)

        do { try context.save() } catch {
            print("[LiftLog] addOneOff save failed: \(error)")
        }
    }

    private var allFieldsInOrder: [SetField] {
        guard let session else { return [] }
        let orderedLogs = session.loggedExercises.sorted { $0.order < $1.order }
        var fields: [SetField] = []
        for log in orderedLogs {
            for set in log.orderedSets {
                if !log.isBodyweight {
                    fields.append(.weight(set.persistentModelID))
                }
                fields.append(.reps(set.persistentModelID))
            }
        }
        return fields
    }

    private func focusNext() {
        guard let current = focusedField else { return }
        let fields = allFieldsInOrder
        guard let idx = fields.firstIndex(of: current), idx + 1 < fields.count else { return }
        focusedField = fields[idx + 1]
    }

    private func focusPrev() {
        guard let current = focusedField else { return }
        let fields = allFieldsInOrder
        guard let idx = fields.firstIndex(of: current), idx > 0 else { return }
        focusedField = fields[idx - 1]
    }

    private var canFocusPrev: Bool {
        guard let current = focusedField else { return false }
        return allFieldsInOrder.firstIndex(of: current).map { $0 > 0 } ?? false
    }

    private var canFocusNext: Bool {
        guard let current = focusedField else { return false }
        let fields = allFieldsInOrder
        return fields.firstIndex(of: current).map { $0 + 1 < fields.count } ?? false
    }

    private var nextDayName: String {
        let ordered = routine.orderedDays
        guard !ordered.isEmpty else { return "—" }
        let next = (routine.currentDayIndex + 1) % ordered.count
        return ordered[next].name
    }

    var body: some View {
        List {
            Section {
                HeroHeader(routine: routine, day: day)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(visibleExercises, id: \.id) { item in
                    ExerciseLogCard(
                        exerciseName: item.name,
                        isBodyweight: item.isBodyweight,
                        order: item.order,
                        session: $session,
                        routine: routine,
                        day: day,
                        onSkip: { skip(item) },
                        focus: $focusedField
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            skip(item)
                        } label: {
                            Label("Skip", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                .onMove(perform: moveExercises)
            }

            Section {
                Button {
                    showingAddExercise = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add exercise")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !skippedItems.isEmpty {
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            skippedExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("SKIPPED TODAY")
                                .font(.caption2.bold())
                                .tracking(0.6)
                                .foregroundStyle(.secondary)
                            Text("· \(skippedItems.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Image(systemName: skippedExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if skippedExpanded {
                        VStack(spacing: 0) {
                            ForEach(Array(skippedItems.enumerated()), id: \.element.key) { idx, item in
                                HStack(spacing: 8) {
                                    Button {
                                        restoreSkipped(key: item.key)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "arrow.uturn.backward")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.accent)
                                            Text(item.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Spacer(minLength: 4)
                                            Text("Restore")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.accent)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        skippedPendingDelete = item
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 28, height: 28)
                                            .background(Color(.tertiarySystemGroupedBackground))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                if idx < skippedItems.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }

            Section {
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
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 80, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            restoreInProgressSession()
        }
        .onChange(of: day.id) { _, _ in
            resetSessionForDayChange()
            restoreInProgressSession()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .keyboard) {
                HStack(spacing: 16) {
                    Button {
                        focusPrev()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(!canFocusPrev)

                    Button {
                        focusNext()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(!canFocusNext)

                    Spacer()

                    Button("Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
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
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet(
                excludedKeys: Set(visibleExercises.map(\.id))
            ) { name, isBodyweight in
                addOneOff(name: name, isBodyweight: isBodyweight)
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Delete \(skippedPendingDelete?.name ?? "this exercise")?",
            isPresented: Binding(
                get: { skippedPendingDelete != nil },
                set: { if !$0 { skippedPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: skippedPendingDelete
        ) { item in
            Button("Delete from routine", role: .destructive) {
                deleteSkipped(key: item.key)
                skippedPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                skippedPendingDelete = nil
            }
        } message: { _ in
            Text("Removes this exercise from the routine template so it won't show up in future sessions. Past logs stay in your history.")
        }
    }

    private func restoreInProgressSession() {
        guard session == nil else { return }
        // No time cutoff: if there's an in-progress session for this
        // routine + day, always restore it so the user can finish it
        // manually no matter how long they were away.
        let candidate = allSessions
            .filter { s in
                s.isCompleted == false
                    && s.dayName == day.name
                    && s.routineName == routine.name
            }
            .max { $0.date < $1.date }
        session = candidate
    }

    private func resetSessionForDayChange() {
        if let s = session {
            let hasRealWork = s.loggedExercises.contains { $0.hasAnyValidSet }
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
            let hasAnyLoggedWork = s.loggedExercises.contains { $0.hasAnyValidSet }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name.uppercased())
                .font(.caption.bold())
                .tracking(1.2)
                .foregroundStyle(Theme.accent)

            Text(day.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                Text("•").foregroundStyle(.tertiary)
                Text("\(day.exercises.count) lift\(day.exercises.count == 1 ? "" : "s")")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

private struct ExerciseLogCard: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var unitPref: UnitPreference

    let exerciseName: String
    let isBodyweight: Bool
    let order: Int
    @Binding var session: WorkoutSession?
    let routine: Routine
    let day: RoutineDay
    let onSkip: () -> Void
    @FocusState.Binding var focus: SetField?

    @Query private var allLogs: [LoggedExercise]

    init(
        exerciseName: String,
        isBodyweight: Bool,
        order: Int,
        session: Binding<WorkoutSession?>,
        routine: Routine,
        day: RoutineDay,
        onSkip: @escaping () -> Void,
        focus: FocusState<SetField?>.Binding
    ) {
        self.exerciseName = exerciseName
        self.isBodyweight = isBodyweight
        self.order = order
        self._session = session
        self.routine = routine
        self.day = day
        self.onSkip = onSkip
        self._focus = focus
    }

    private var previousLogs: [LoggedExercise] {
        let key = exerciseName.normalizedExerciseKey
        return allLogs.filter { log in
            log.exerciseName.normalizedExerciseKey == key
                && log.session?.isCompleted == true
                && log.session !== session
                && log.hasAnyValidSet
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
        session?.loggedExercises.first { $0.exerciseName == exerciseName }
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
            Text(exerciseName)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            NavigationLink {
                ExerciseHistoryView(exerciseName: exerciseName)
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
                Text(exerciseName)
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ExerciseHistoryView(exerciseName: exerciseName)
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
                            SetRowView(
                                entry: entry,
                                isBodyweight: isBodyweight,
                                focus: $focus
                            )
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
        let useful = log.validSets
        let isBW = log.effectiveIsBodyweight
        let topSet: SetEntry? = isBW
            ? useful.max { $0.reps < $1.reps }
            : useful.max { $0.weight < $1.weight }
        return Button {
            log.isCompleted = false
            save("expandExercise")
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text("\(useful.count) set\(useful.count == 1 ? "" : "s")")
                        if let top = topSet {
                            Text("•").foregroundStyle(.tertiary)
                            if isBW {
                                Text("top \(top.reps) reps")
                            } else {
                                Text("top \(top.weight.formattedWeight(unit: unitPref.unit)) × \(top.reps)")
                            }
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
        let log = LoggedExercise(
            exerciseName: exerciseName,
            order: order,
            isBodyweight: isBodyweight
        )
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
                let isBW = prev.effectiveIsBodyweight
                FlowLayout(spacing: 4) {
                    ForEach(prev.orderedSets) { s in
                        Text(isBW ? "\(s.reps) reps" : "\(formatWeight(s.weight, unit: unit))×\(s.reps)")
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

struct SetRowView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    @Bindable var entry: SetEntry
    let isBodyweight: Bool
    @FocusState.Binding var focus: SetField?

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.order + 1)")
                .font(.callout.bold())
                .frame(width: 26, height: 26)
                .background(Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(.secondary)
                .clipShape(Circle())

            if !isBodyweight {
                NumericField(
                    value: $entry.weight,
                    placeholder: "0",
                    suffix: unitPref.unit.label,
                    focus: $focus,
                    focusValue: .weight(entry.persistentModelID)
                )
                Text("×").foregroundStyle(.secondary)
            }
            NumericIntField(
                value: $entry.reps,
                placeholder: "0",
                focus: $focus,
                focusValue: .reps(entry.persistentModelID)
            )
            if isBodyweight {
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
}

struct SwipeableRow<Content: View>: View {
    let onDelete: () -> Void
    var allowsFullSwipeCommit: Bool = true
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
                                if allowsFullSwipeCommit && value.translation.width < -triggerThreshold {
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

struct NumericField: View {
    @Binding var value: Double
    let placeholder: String
    let suffix: String
    @FocusState.Binding var focus: SetField?
    let focusValue: SetField

    @State private var text: String = ""

    private var isFocused: Bool { focus == focusValue }

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($focus, equals: focusValue)
                .onAppear { syncFromValue() }
                .onChange(of: text) { _, newText in
                    let cleaned = newText.replacingOccurrences(of: ",", with: ".")
                    value = Double(cleaned) ?? 0
                }
                .onChange(of: value) { _, _ in
                    if !isFocused { syncFromValue() }
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

struct NumericIntField: View {
    @Binding var value: Int
    let placeholder: String
    @FocusState.Binding var focus: SetField?
    let focusValue: SetField

    @State private var text: String = ""

    private var isFocused: Bool { focus == focusValue }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(minWidth: 52)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($focus, equals: focusValue)
            .onAppear { syncFromValue() }
            .onChange(of: text) { _, newText in
                value = Int(newText) ?? 0
            }
            .onChange(of: value) { _, _ in
                if !isFocused { syncFromValue() }
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

// MARK: - Add exercise sheet

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]
    @Query private var allLogs: [LoggedExercise]

    let excludedKeys: Set<String>
    let onAdd: (_ name: String, _ isBodyweight: Bool) -> Void

    @State private var query: String = ""
    @State private var isBodyweight: Bool = false

    private struct Suggestion: Identifiable {
        let id: String
        let name: String
        let isBodyweight: Bool
    }

    private var allSuggestions: [Suggestion] {
        var bestName: [String: String] = [:]
        var bestBW: [String: Bool] = [:]
        for ex in allExercises {
            let key = ex.name.normalizedExerciseKey
            guard !key.isEmpty else { continue }
            if (bestName[key]?.count ?? 0) < ex.name.count {
                bestName[key] = ex.name
            }
            bestBW[key] = (bestBW[key] ?? false) || ex.isBodyweight
        }
        for log in allLogs {
            let key = log.exerciseName.normalizedExerciseKey
            guard !key.isEmpty else { continue }
            if (bestName[key]?.count ?? 0) < log.exerciseName.count {
                bestName[key] = log.exerciseName
            }
            bestBW[key] = (bestBW[key] ?? false) || log.isBodyweight
        }
        return bestName.keys
            .filter { !excludedKeys.contains($0) }
            .compactMap { key in
                guard let name = bestName[key] else { return nil }
                return Suggestion(id: key, name: name, isBodyweight: bestBW[key] ?? false)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredSuggestions: [Suggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return allSuggestions }
        let q = trimmed.lowercased()
        return allSuggestions.filter { $0.name.lowercased().contains(q) }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var canCreate: Bool {
        let key = trimmedQuery.normalizedExerciseKey
        return !key.isEmpty
            && !excludedKeys.contains(key)
            && !filteredSuggestions.contains { $0.id == key }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Exercise name", text: $query)
                        .submitLabel(.done)
                    Toggle("Bodyweight (reps only)", isOn: $isBodyweight)
                } footer: {
                    Text("Pick an existing exercise below, or type a new name to create one.")
                }

                if !filteredSuggestions.isEmpty {
                    Section("Existing") {
                        ForEach(filteredSuggestions) { s in
                            Button {
                                onAdd(s.name, s.isBodyweight)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(s.name)
                                        .foregroundStyle(.primary)
                                    if s.isBodyweight {
                                        Text("BW")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .foregroundStyle(.secondary)
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(trimmedQuery, isBodyweight)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCreate)
                }
            }
        }
    }
}
