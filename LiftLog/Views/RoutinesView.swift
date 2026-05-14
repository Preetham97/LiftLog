import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var path: [Routine] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ScreenBackground()
                if routines.isEmpty {
                    EmptyRoutinesState(
                        onUseTemplate: { createFromTemplate(.fiveDaySplit) },
                        onBlank: createBlank
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(routines) { routine in
                                NavigationLink(value: routine) {
                                    RoutineCard(routine: routine, onMakeActive: { makeActive(routine) })
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if !routine.isActive {
                                        Button {
                                            makeActive(routine)
                                        } label: {
                                            Label("Set as active", systemImage: "star")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        delete(routine)
                                    } label: {
                                        Label("Delete routine", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            createBlank()
                        } label: {
                            Label("Blank routine", systemImage: "doc")
                        }
                        Button {
                            createFromTemplate(.fiveDaySplit)
                        } label: {
                            Label("5-Day Split (starter)", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private func createBlank() {
        let shouldBeActive = !routines.contains(where: \.isActive)
        let routine = Routine(name: "New Routine", isActive: shouldBeActive)
        context.insert(routine)
        for (i, name) in ["Push", "Pull", "Legs"].enumerated() {
            let day = RoutineDay(name: name, order: i)
            context.insert(day)
            routine.days.append(day)
        }
        save(routine)
    }

    private func createFromTemplate(_ template: RoutineTemplate) {
        let shouldBeActive = !routines.contains(where: \.isActive)
        let routine = Routine(name: template.name, isActive: shouldBeActive)
        context.insert(routine)
        for (i, dayTemplate) in template.days.enumerated() {
            let day = RoutineDay(name: dayTemplate.name, order: i)
            context.insert(day)
            routine.days.append(day)
            for (j, ex) in dayTemplate.exercises.enumerated() {
                let exercise = Exercise(name: ex.name, order: j, isBodyweight: ex.isBodyweight)
                context.insert(exercise)
                day.exercises.append(exercise)
            }
        }
        save(routine)
    }

    private func save(_ routine: Routine) {
        do {
            try context.save()
            path.append(routine)
        } catch {
            print("[LiftLog] save new routine failed: \(error)")
        }
    }

    private func makeActive(_ routine: Routine) {
        for r in routines { r.isActive = (r.id == routine.id) }
        try? context.save()
    }

    private func delete(_ routine: Routine) {
        let wasActive = routine.isActive
        context.delete(routine)
        do {
            try context.save()
        } catch {
            print("[LiftLog] delete routine failed: \(error)")
        }
        if wasActive, let fallback = routines.first {
            fallback.isActive = true
            try? context.save()
        }
    }
}

private struct EmptyRoutinesState: View {
    let onUseTemplate: () -> Void
    let onBlank: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No routines yet")
                .font(.title2.bold())
            Text("Start with a 5-day split or build your own from scratch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Button(action: onUseTemplate) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("5-Day Split")
                            .fontWeight(.semibold)
                    }
                    Text("Chest · Back · Legs · Shoulders · Mixed")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: 280, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Button("Or start blank", action: onBlank)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine
    let onMakeActive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(routine.name)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                if routine.isActive {
                    PillLabel(text: "ACTIVE")
                } else {
                    Button("Set Active", action: onMakeActive)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                MetricItem(value: "\(routine.days.count)", label: "DAYS")
                MetricItem(value: routine.nextDay?.name ?? "—", label: "UP NEXT")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .card()
    }
}

private struct MetricItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text(label)
                .font(.caption2.bold())
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Routine detail (flat, inline-expandable days)

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var routine: Routine
    @Query private var allRoutines: [Routine]
    @Query private var allExercises: [Exercise]
    @Query private var allLogs: [LoggedExercise]

    @State private var expandedDayID: PersistentIdentifier?
    @State private var showingDeleteConfirm = false
    @State private var dayPendingDelete: RoutineDay?

    private var knownExerciseNames: [String] {
        var bestByKey: [String: String] = [:]
        for name in allExercises.map(\.name) + allLogs.map(\.exerciseName) {
            let key = name.normalizedExerciseKey
            guard !key.isEmpty else { continue }
            // Prefer the longest variant as the canonical display
            // (usually the most carefully-typed one).
            if (bestByKey[key]?.count ?? 0) < name.count {
                bestByKey[key] = name
            }
        }
        return bestByKey.values.sorted()
    }

    /// Exercise name keys that already have at least one LoggedExercise.
    /// The BW toggle is disabled for these so the user can't retro-flip the
    /// type and silently mix metrics across past and future logs.
    private var lockedBodyweightKeys: Set<String> {
        Set(allLogs.map { $0.exerciseName.normalizedExerciseKey })
    }

    var body: some View {
        List {
            Section {
                TextField("Routine name", text: $routine.name)
                    .font(.headline)
                if routine.isActive {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Active routine")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        for r in allRoutines { r.isActive = (r.id == routine.id) }
                        try? context.save()
                    } label: {
                        Label("Set as active", systemImage: "star")
                    }
                }
            } header: {
                Text("Routine")
            }

            Section {
                ForEach(routine.orderedDays) { day in
                    DayDisclosure(
                        day: day,
                        isNext: day.id == routine.nextDay?.id,
                        knownExerciseNames: knownExerciseNames,
                        lockedBodyweightKeys: lockedBodyweightKeys,
                        isExpanded: Binding(
                            get: { expandedDayID == day.persistentModelID },
                            set: { expanded in
                                expandedDayID = expanded ? day.persistentModelID : nil
                            }
                        )
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if day.id != routine.nextDay?.id {
                            Button {
                                setNextDay(day)
                            } label: {
                                Label("Set Next", systemImage: "arrow.right.circle.fill")
                            }
                            .tint(Theme.accent)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        // No `role: .destructive` here so the row doesn't
                        // animate away before the confirmation has resolved.
                        Button {
                            dayPendingDelete = day
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }

                Button(action: addDay) {
                    Label("Add day", systemImage: "plus")
                }
            } header: {
                Text("Cycle")
            } footer: {
                Text("Tap a day to expand and edit its exercises. Swipe right to set as next, left to delete.")
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete routine", systemImage: "trash")
                }
            }
        }
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete \(routine.name.isEmpty ? "this routine" : routine.name)?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete routine", role: .destructive) {
                deleteRoutine()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your logged sessions and history won't be touched — only this routine's days and exercise list go away.")
        }
        .confirmationDialog(
            "Delete \(dayPendingDelete?.name.isEmpty == false ? dayPendingDelete!.name : "this day")?",
            isPresented: Binding(
                get: { dayPendingDelete != nil },
                set: { if !$0 { dayPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: dayPendingDelete
        ) { day in
            Button("Delete day", role: .destructive) {
                delete(day)
                dayPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                dayPendingDelete = nil
            }
        } message: { _ in
            Text("This removes the day and its exercise template from the routine. Past logged sessions for this day name stay in your history.")
        }
    }

    private func deleteRoutine() {
        let wasActive = routine.isActive
        context.delete(routine)
        do { try context.save() } catch {
            print("[LiftLog] delete routine failed: \(error)")
        }
        if wasActive, let fallback = allRoutines.first {
            fallback.isActive = true
            try? context.save()
        }
        dismiss()
    }

    private func addDay() {
        let order = (routine.days.map(\.order).max() ?? -1) + 1
        let day = RoutineDay(name: "Day \(order + 1)", order: order)
        context.insert(day)
        routine.days.append(day)
        try? context.save()
    }

    private func setNextDay(_ day: RoutineDay) {
        let ordered = routine.orderedDays
        guard let idx = ordered.firstIndex(where: { $0.id == day.id }) else { return }
        routine.currentDayIndex = idx
        try? context.save()
    }

    private func delete(_ day: RoutineDay) {
        context.delete(day)
        try? context.save()
    }
}

private struct DayDisclosure: View {
    @Environment(\.modelContext) private var context
    @Bindable var day: RoutineDay
    let isNext: Bool
    let knownExerciseNames: [String]
    let lockedBodyweightKeys: Set<String>
    @Binding var isExpanded: Bool

    @State private var newExerciseName: String = ""

    private var suggestions: [String] {
        let query = newExerciseName.normalizedExerciseKey
        guard query.count >= 1 else { return [] }
        let existingKeysInDay = Set(day.exercises.map { $0.name.normalizedExerciseKey })
        return knownExerciseNames
            .filter { name in
                let key = name.normalizedExerciseKey
                return key != query
                    && key.contains(query)
                    && !existingKeysInDay.contains(key)
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 6) {
                ForEach(day.orderedExercises) { ex in
                    InlineExerciseRow(
                        exercise: ex,
                        isTypeLocked: lockedBodyweightKeys.contains(ex.name.normalizedExerciseKey),
                        onDelete: { delete(ex) }
                    )
                }

                HStack(spacing: 8) {
                    TextField("Add exercise", text: $newExerciseName)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(addExercise)
                    Button(action: addExercise) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(canAdd ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                }
                .padding(.vertical, 6)

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { name in
                            Button {
                                newExerciseName = name
                                addExercise()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(name)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                            }
                            .buttonStyle(.plain)
                            if name != suggestions.last {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isNext ? Theme.accent : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 30, height: 30)
                    Image(systemName: isNext ? "play.fill" : "calendar")
                        .font(.caption)
                        .foregroundStyle(isNext ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        TextField("Day name", text: $day.name)
                            .font(.body.weight(.medium))
                            .textFieldStyle(.plain)
                        if isNext {
                            PillLabel(text: "NEXT")
                        }
                    }
                    Text("\(day.exercises.count) lift\(day.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var canAdd: Bool {
        !newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let key = trimmed.normalizedExerciseKey

        // Don't add the same exercise twice on the same day
        if day.exercises.contains(where: { $0.name.normalizedExerciseKey == key }) {
            newExerciseName = ""
            return
        }

        // Reuse the canonical capitalization if we've seen this lift before
        let canonical = knownExerciseNames.first { $0.normalizedExerciseKey == key } ?? trimmed
        let order = (day.exercises.map(\.order).max() ?? -1) + 1
        let ex = Exercise(name: canonical, order: order)
        context.insert(ex)
        day.exercises.append(ex)
        try? context.save()
        newExerciseName = ""
    }

    private func delete(_ exercise: Exercise) {
        context.delete(exercise)
        try? context.save()
    }
}

private struct InlineExerciseRow: View {
    @Bindable var exercise: Exercise
    let isTypeLocked: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Exercise name", text: $exercise.name)
                .textFieldStyle(.plain)
            Button {
                guard !isTypeLocked else { return }
                exercise.isBodyweight.toggle()
            } label: {
                HStack(spacing: 3) {
                    if isTypeLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }
                    Text("BW")
                        .font(.caption2.bold())
                        .tracking(0.4)
                }
                .foregroundStyle(exercise.isBodyweight ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(exercise.isBodyweight ? Theme.accent : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(
                        exercise.isBodyweight ? Color.clear : Color.secondary.opacity(0.4),
                        lineWidth: 1
                    )
                )
                .opacity(isTypeLocked ? 0.65 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isTypeLocked)
            .help(isTypeLocked ? "Locked — this exercise already has logged history." : "")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
