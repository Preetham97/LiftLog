import SwiftUI
import SwiftData

/// Editor for a previously-ended workout session. Mirrors the Today
/// session UI (set rows, swipe-to-delete, add set, add exercise) but
/// targets an existing `WorkoutSession` instead of creating a new one.
/// All changes save reactively via SwiftData; stats / history / charts
/// pick them up automatically.
struct EditSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var unitPref: UnitPreference

    @Bindable var session: WorkoutSession

    @State private var showingAddExercise = false
    @FocusState private var focusedField: SetField?

    private var loggedExercises: [LoggedExercise] {
        session.loggedExercises.sorted { $0.order < $1.order }
    }

    private var existingKeys: Set<String> {
        Set(loggedExercises.map { $0.exerciseName.normalizedExerciseKey })
    }

    // Field navigation across all editable set fields in this session.
    private var allFieldsInOrder: [SetField] {
        var fields: [SetField] = []
        for log in loggedExercises {
            for set in log.orderedSets {
                fields.append(.weight(set.persistentModelID))
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

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EDITING")
                        .font(.caption2.bold())
                        .tracking(1.2)
                        .foregroundStyle(Theme.accent)
                    Text(session.dayName)
                        .font(.title2.weight(.bold))
                    Text(session.date.formatted(date: .complete, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .padding(.bottom, 6)

                ForEach(loggedExercises) { log in
                    SwipeableRow(
                        onDelete: { delete(log) },
                        allowsFullSwipeCommit: false
                    ) {
                        EditableExerciseCard(log: log, focus: $focusedField, unit: unitPref.unit)
                    }
                }

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
                .padding(.top, 4)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .keyboard) {
                HStack(spacing: 16) {
                    Button { focusPrev() } label: {
                        Image(systemName: "chevron.up")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(!canFocusPrev)

                    Button { focusNext() } label: {
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
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet(excludedKeys: existingKeys) { name, isBodyweight in
                addExercise(name: name, isBodyweight: isBodyweight)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func delete(_ log: LoggedExercise) {
        context.delete(log)
        save("deleteLog")
    }

    private func addExercise(name: String, isBodyweight: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let key = trimmed.normalizedExerciseKey
        guard !existingKeys.contains(key) else { return }

        let nextOrder = (loggedExercises.last?.order ?? -1) + 1
        let log = LoggedExercise(
            exerciseName: trimmed,
            order: nextOrder,
            isCompleted: true,
            isBodyweight: isBodyweight
        )
        context.insert(log)
        log.session = session
        session.loggedExercises.append(log)
        save("addExercise")
    }

    private func save(_ source: String) {
        do {
            try context.save()
        } catch {
            print("[LiftLog] edit save failed in \(source): \(error)")
        }
    }
}

private struct EditableExerciseCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var log: LoggedExercise
    @FocusState.Binding var focus: SetField?
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(log.exerciseName)
                    .font(.headline)
                if log.effectiveIsBodyweight {
                    Text("BW")
                        .font(.caption2.bold())
                        .tracking(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(log.orderedSets) { entry in
                    SwipeableRow(onDelete: { delete(entry) }) {
                        SetRowView(
                            entry: entry,
                            isBodyweight: log.effectiveIsBodyweight,
                            focus: $focus
                        )
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .card()
    }

    private func addSet() {
        let order = (log.orderedSets.last?.order ?? -1) + 1
        let entry = SetEntry(order: order, weight: 0, reps: 0)
        context.insert(entry)
        entry.loggedExercise = log
        log.sets.append(entry)
        save("addSet")
    }

    private func delete(_ entry: SetEntry) {
        context.delete(entry)
        save("deleteSet")
    }

    private func save(_ source: String) {
        do {
            try context.save()
        } catch {
            print("[LiftLog] edit card save failed in \(source): \(error)")
        }
    }
}
