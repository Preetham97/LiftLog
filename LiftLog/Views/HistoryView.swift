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
                        MonthStats(
                            displayedMonth: monthAnchor,
                            sessions: loggedSessions
                        )
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

    private var loggedSessions: [WorkoutSession] {
        sessions.filter { s in
            s.isCompleted && s.loggedExercises.contains { $0.hasAnyValidSet }
        }
    }

    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(loggedSessions.map { cal.startOfDay(for: $0.date) })
    }
}

// MARK: - Month stats strip

private struct MonthStats: View {
    let displayedMonth: Date
    let sessions: [WorkoutSession]

    private var sessionsThisMonth: Int {
        let cal = Calendar.current
        return sessions.filter {
            cal.isDate($0.date, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    private var sessionsLastMonth: Int {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .month, value: -1, to: displayedMonth) else { return 0 }
        return sessions.filter { cal.isDate($0.date, equalTo: prev, toGranularity: .month) }.count
    }

    private var activeDaysThisMonth: Int {
        let cal = Calendar.current
        let dates = sessions
            .filter { cal.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
            .map { cal.startOfDay(for: $0.date) }
        return Set(dates).count
    }

    private var delta: Int { sessionsThisMonth - sessionsLastMonth }

    private var deltaColor: Color {
        if delta > 0 { return .green }
        if delta < 0 { return .red }
        return .secondary
    }

    private var deltaIcon: String {
        if delta > 0 { return "arrow.up.right" }
        if delta < 0 { return "arrow.down.right" }
        return "equal"
    }

    var body: some View {
        HStack(spacing: 10) {
            StatTile(
                value: "\(sessionsThisMonth)",
                label: "SESSIONS",
                trailing: AnyView(deltaBadge)
            )
            StatTile(
                value: "\(activeDaysThisMonth)",
                label: "ACTIVE DAYS",
                trailing: AnyView(EmptyView())
            )
        }
    }

    private var deltaBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: deltaIcon)
                .font(.caption2.bold())
            Text("\(abs(delta))")
                .font(.caption2.bold().monospacedDigit())
        }
        .foregroundStyle(deltaColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(deltaColor.opacity(0.14))
        .clipShape(Capsule())
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let trailing: AnyView

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                Text(label)
                    .font(.caption2.bold())
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .card(padding: 14)
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
    @Query private var allLogs: [LoggedExercise]

    private var sessionsThatDay: [WorkoutSession] {
        let cal = Calendar.current
        return allSessions
            .filter { $0.isCompleted && cal.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sessionsThatDay) { session in
                        SessionSummaryCard(session: session, allLogs: allLogs, unit: unitPref.unit)
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
    let allLogs: [LoggedExercise]
    let unit: WeightUnit

    private var loggedExercises: [LoggedExercise] {
        session.loggedExercises
            .filter { $0.hasAnyValidSet }
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
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(loggedExercises) { log in
                        ReadOnlyExerciseBlock(log: log, allLogs: allLogs, unit: unit)
                    }
                }
            }
        }
        .card()
    }
}

private struct ReadOnlyExerciseBlock: View {
    let log: LoggedExercise
    let allLogs: [LoggedExercise]
    let unit: WeightUnit

    private var sets: [SetEntry] { log.validSets }
    private var isBodyweight: Bool { log.effectiveIsBodyweight }

    /// All completed logs of this exercise sorted oldest → newest, paired with
    /// the "top metric" value for the session.
    private var ratedLogs: [(log: LoggedExercise, value: Double)] {
        let key = log.exerciseName.normalizedExerciseKey
        return allLogs
            .filter { l in
                l.exerciseName.normalizedExerciseKey == key
                    && l.session?.isCompleted == true
                    && l.hasAnyValidSet
            }
            .compactMap { l -> (LoggedExercise, Date, Double)? in
                guard let date = l.session?.date else { return nil }
                let value: Double
                if l.effectiveIsBodyweight {
                    value = Double(l.validSets.map(\.reps).max() ?? 0)
                } else {
                    value = l.validSets.map(\.estimatedOneRepMax).max() ?? 0
                }
                return (l, date, value)
            }
            .sorted { $0.1 < $1.1 }
            .map { ($0.0, $0.2) }
    }

    private var currentValue: Double {
        let currentID = log.session?.persistentModelID
        return ratedLogs.first(where: { $0.log.session?.persistentModelID == currentID })?.value ?? 0
    }

    /// Difference vs the most recent session of the same exercise that occurred
    /// strictly before this one. nil if this is the first session.
    private var deltaVsPrevious: Double? {
        let currentID = log.session?.persistentModelID
        var previousValue: Double?
        for (l, value) in ratedLogs {
            if l.session?.persistentModelID == currentID { break }
            previousValue = value
        }
        guard let prev = previousValue else { return nil }
        return currentValue - prev
    }

    private var format: MetricFormat {
        MetricFormat.from(isBodyweight: isBodyweight, unit: unit)
    }

    var body: some View {
        NavigationLink {
            ExerciseProgressView(exerciseName: log.exerciseName)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(log.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(format.format(currentValue))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(format.shortLabel)
                        .font(.caption2.bold())
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    if let delta = deltaVsPrevious {
                        TrendBadge(delta: delta, format: format)
                    }
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { idx, s in
                        HStack(spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 18, alignment: .leading)
                            if isBodyweight {
                                Text("\(s.reps) reps")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.primary)
                            } else {
                                Text("\(s.weight.formattedWeight(unit: unit)) × \(s.reps) reps")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
