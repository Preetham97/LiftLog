import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                if routines.isEmpty {
                    EmptyRoutinesState()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(routines) { routine in
                                NavigationLink {
                                    RoutineDetailView(routine: routine)
                                } label: {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewRoutineSheet()
            }
        }
    }

    private func makeActive(_ routine: Routine) {
        for r in routines { r.isActive = (r.id == routine.id) }
        try? context.save()
    }
}

private struct EmptyRoutinesState: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("No routines yet")
                .font(.title2.bold())
            Text("Tap + to build your first routine cycle — push/pull/legs, upper/lower, anything goes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
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

private struct NewRoutineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var existingRoutines: [Routine]

    @State private var name = ""
    @State private var dayNames: [String] = ["Push", "Pull", "Legs"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Name (e.g. PPL)", text: $name)
                }
                Section("Days in cycle") {
                    ForEach(dayNames.indices, id: \.self) { i in
                        TextField("Day \(i + 1)", text: $dayNames[i])
                    }
                    .onDelete { offsets in
                        dayNames.remove(atOffsets: offsets)
                    }
                    Button {
                        dayNames.append("Day \(dayNames.count + 1)")
                    } label: {
                        Label("Add day", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || dayNames.isEmpty)
                }
            }
        }
    }

    private func create() {
        let shouldBeActive = !existingRoutines.contains(where: \.isActive)
        let routine = Routine(name: name.trimmingCharacters(in: .whitespaces), isActive: shouldBeActive)
        context.insert(routine)
        for (i, dn) in dayNames.enumerated() where !dn.trimmingCharacters(in: .whitespaces).isEmpty {
            let day = RoutineDay(name: dn, order: i)
            day.routine = routine
            context.insert(day)
        }
        try? context.save()
        dismiss()
    }
}

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine
    @Query private var allRoutines: [Routine]

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 16) {
                    HeaderCard(routine: routine, allRoutines: allRoutines, context: context)
                    DaysSection(routine: routine)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HeaderCard: View {
    @Bindable var routine: Routine
    let allRoutines: [Routine]
    let context: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ROUTINE")
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                if routine.isActive {
                    PillLabel(text: "ACTIVE")
                }
            }
            TextField("Routine name", text: $routine.name)
                .font(.title2.bold())
                .textFieldStyle(.plain)

            if !routine.isActive {
                Button {
                    for r in allRoutines { r.isActive = (r.id == routine.id) }
                    try? context.save()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Set as active routine")
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
}

private struct DaysSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CYCLE")
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Swipe a day to set it as next")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(routine.orderedDays) { day in
                    DayRow(
                        day: day,
                        isNext: day.id == routine.nextDay?.id,
                        onSetNext: { setNextDay(day) },
                        onDelete: { delete(day) }
                    )
                }
                Button(action: addDay) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add day")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Theme.accentSoft)
                    .foregroundStyle(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                }
            }
        }
    }

    private func addDay() {
        let order = (routine.days.map(\.order).max() ?? -1) + 1
        let day = RoutineDay(name: "Day \(order + 1)", order: order)
        day.routine = routine
        context.insert(day)
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

private struct DayRow: View {
    let day: RoutineDay
    let isNext: Bool
    let onSetNext: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationLink {
            RoutineDayDetailView(day: day)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isNext ? Theme.accent : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 36, height: 36)
                    Image(systemName: isNext ? "play.fill" : "calendar")
                        .font(.callout)
                        .foregroundStyle(isNext ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(day.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        if isNext {
                            PillLabel(text: "NEXT")
                        }
                    }
                    Text("\(day.exercises.count) lift\(day.exercises.count == 1 ? "" : "s")")
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
                RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isNext {
                Button(action: onSetNext) {
                    Label("Set Next", systemImage: "arrow.right.circle.fill")
                }
                .tint(Theme.accent)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct RoutineDayDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var day: RoutineDay
    @State private var newName = ""

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DAY")
                            .font(.caption2.bold())
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        TextField("Day name", text: $day.name)
                            .font(.title2.bold())
                            .textFieldStyle(.plain)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("EXERCISES")
                            .font(.caption2.bold())
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            ForEach(day.orderedExercises) { ex in
                                ExerciseRow(exercise: ex, onDelete: { delete(ex) })
                            }
                            HStack(spacing: 8) {
                                TextField("Add exercise (e.g. Bench Press)", text: $newName)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                                Button(action: addExercise) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(newName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Theme.accent)
                                }
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addExercise() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let order = (day.exercises.map(\.order).max() ?? -1) + 1
        let ex = Exercise(name: trimmed, order: order)
        ex.day = day
        context.insert(ex)
        try? context.save()
        newName = ""
    }

    private func delete(_ exercise: Exercise) {
        context.delete(exercise)
        try? context.save()
    }
}

private struct ExerciseRow: View {
    @Bindable var exercise: Exercise
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.callout)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentSoft)
                .clipShape(Circle())
            TextField("Exercise name", text: $exercise.name)
                .textFieldStyle(.plain)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
