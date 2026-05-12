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
                    EmptyRoutinesState(onCreate: createAndOpen)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(routines) { routine in
                                NavigationLink(value: routine) {
                                    RoutineCard(routine: routine, onMakeActive: { makeActive(routine) })
                                }
                                .buttonStyle(.plain)
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
                    Button(action: createAndOpen) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private func createAndOpen() {
        let shouldBeActive = !routines.contains(where: \.isActive)
        let routine = Routine(name: "New Routine", isActive: shouldBeActive)
        context.insert(routine)
        for (i, name) in ["Push", "Pull", "Legs"].enumerated() {
            let day = RoutineDay(name: name, order: i)
            context.insert(day)
            routine.days.append(day)
        }
        do {
            try context.save()
            path.append(routine)
        } catch {
            print("[LiftLog] createAndOpen failed: \(error)")
        }
    }

    private func makeActive(_ routine: Routine) {
        for r in routines { r.isActive = (r.id == routine.id) }
        try? context.save()
    }
}

private struct EmptyRoutinesState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("No routines yet")
                .font(.title2.bold())
            Text("Build your first routine cycle — push/pull/legs, upper/lower, anything goes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Button(action: onCreate) {
                Label("Create routine", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
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
    @Bindable var routine: Routine
    @Query private var allRoutines: [Routine]
    @Query private var allExercises: [Exercise]
    @Query private var allLogs: [LoggedExercise]

    @State private var expandedDayID: PersistentIdentifier?

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
                            .foregroundStyle(Theme.accent)
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
                        Button(role: .destructive) {
                            delete(day)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button(action: addDay) {
                    Label("Add day", systemImage: "plus")
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("Cycle")
            } footer: {
                Text("Tap a day to expand and edit its exercises. Swipe right to set as next, left to delete.")
            }
        }
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
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
                    InlineExerciseRow(exercise: ex, onDelete: { delete(ex) })
                }

                HStack(spacing: 8) {
                    TextField("Add exercise", text: $newExerciseName)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(addExercise)
                    Button(action: addExercise) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(canAdd ? Theme.accent : .secondary)
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
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
            TextField("Exercise name", text: $exercise.name)
                .textFieldStyle(.plain)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
