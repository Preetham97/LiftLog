import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @State private var monthAnchor: Date = .now
    @State private var selectedDay: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        MonthSwitcher(anchor: $monthAnchor)
                        CalendarGrid(
                            month: monthAnchor,
                            sessionDays: sessionDays,
                            selectedDay: $selectedDay
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("History")
            .navigationDestination(item: $selectedDay) { day in
                DaySessionsView(day: day)
            }
        }
    }

    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(sessions.map { cal.startOfDay(for: $0.date) })
    }
}

// MARK: - Month switcher

private struct MonthSwitcher: View {
    @Binding var anchor: Date

    private var title: String {
        anchor.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        HStack {
            Button {
                shift(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            Button {
                shift(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func shift(by months: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: months, to: anchor) {
            withAnimation(.easeInOut(duration: 0.18)) { anchor = new }
        }
    }
}

// MARK: - Calendar grid

private struct CalendarGrid: View {
    let month: Date
    let sessionDays: Set<Date>
    @Binding var selectedDay: Date?

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        // Rotate so it starts with the user's first weekday.
        let firstWeekday = cal.firstWeekday - 1
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
    }

    private var cells: [Date?] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = interval.start
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 0

        // Padding before the first day so it lands under the correct weekday column.
        let weekdayOfFirst = cal.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - cal.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            result.append(cal.date(byAdding: .day, value: offset, to: firstDay))
        }
        // Trailing blanks to round out the last week.
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym.uppercased())
                        .font(.caption2.bold())
                        .tracking(0.4)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(cells.indices, id: \.self) { idx in
                    if let day = cells[idx] {
                        let normalized = Calendar.current.startOfDay(for: day)
                        DayCell(
                            day: day,
                            hasSession: sessionDays.contains(normalized),
                            isToday: Calendar.current.isDateInToday(day)
                        ) {
                            if sessionDays.contains(normalized) {
                                selectedDay = day
                            }
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .card()
    }
}

private struct DayCell: View {
    let day: Date
    let hasSession: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        let dayNumber = Calendar.current.component(.day, from: day)
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(textColor)
                Circle()
                    .fill(hasSession ? Theme.accent : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isToday ? Theme.accentSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasSession)
        .opacity(hasSession || isToday ? 1 : 0.55)
    }

    private var textColor: Color {
        if isToday { return Theme.accent }
        return hasSession ? .primary : .secondary
    }
}

// MARK: - Read-only day detail

struct DaySessionsView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    let day: Date

    @Query private var allSessions: [WorkoutSession]

    private var sessionsThatDay: [WorkoutSession] {
        let cal = Calendar.current
        return allSessions
            .filter { cal.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sessionsThatDay) { session in
                        SessionSummaryCard(session: session, unit: unitPref.unit)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(day.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SessionSummaryCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    private var loggedExercises: [LoggedExercise] {
        session.loggedExercises
            .filter { log in log.orderedSets.contains { $0.weight > 0 && $0.reps > 0 } }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.dayName)
                        .font(.headline)
                    if !session.routineName.isEmpty {
                        Text("•").foregroundStyle(.tertiary)
                        Text(session.routineName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(session.date.formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if loggedExercises.isEmpty {
                Text("No sets logged this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(loggedExercises) { log in
                        ReadOnlyExerciseBlock(log: log, unit: unit)
                    }
                }
            }
        }
        .card()
    }
}

private struct ReadOnlyExerciseBlock: View {
    let log: LoggedExercise
    let unit: WeightUnit

    private var sets: [SetEntry] {
        log.orderedSets.filter { $0.weight > 0 && $0.reps > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(log.exerciseName)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { idx, s in
                    HStack(spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, alignment: .leading)
                        Text("\(s.weight.formattedWeight(unit: unit)) × \(s.reps) reps")
                            .font(.callout.monospacedDigit())
                        Spacer()
                    }
                }
            }
        }
    }
}
