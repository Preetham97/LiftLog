import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    @Query private var allLoggedExercises: [LoggedExercise]

    private var loggedExercises: [LoggedExercise] {
        allLoggedExercises.filter { log in
            log.orderedSets.contains { $0.weight > 0 && $0.reps > 0 }
        }
    }

    struct ExerciseSummary: Identifiable {
        let id: String
        let name: String
        let latestE1RM: Double
        let sessionCount: Int
        let trend: Double
        let lastSessionDate: Date
        let lastActivityAt: Date
    }

    private var summaries: [ExerciseSummary] {
        let grouped = Dictionary(grouping: loggedExercises, by: { $0.exerciseName.normalizedExerciseKey })
        return grouped.compactMap { key, logs in
            // Pick the most recent variant of the name as the display string.
            let displayName = logs
                .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }?
                .exerciseName ?? key

            let dated = logs.compactMap { log -> (Date, Double)? in
                guard let d = log.session?.date else { return nil }
                let top = log.orderedSets.map(\.estimatedOneRepMax).max() ?? 0
                guard top > 0 else { return nil }
                return (d, top)
            }.sorted { $0.0 < $1.0 }
            guard let last = dated.last else { return nil }
            let prev = dated.dropLast().last?.1 ?? last.1
            let trend = last.1 - prev

            // The most recent set across all of this exercise's logs.
            // Falls back to the session date so ties never reach the sort.
            let latestSetAt = logs
                .flatMap { $0.orderedSets }
                .filter { $0.weight > 0 && $0.reps > 0 }
                .map(\.completedAt)
                .max() ?? last.0

            return ExerciseSummary(
                id: key,
                name: displayName,
                latestE1RM: last.1,
                sessionCount: dated.count,
                trend: trend,
                lastSessionDate: last.0,
                lastActivityAt: latestSetAt
            )
        }.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    private var activeSummaries: [ExerciseSummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        return summaries.filter { $0.lastActivityAt >= cutoff }
    }

    private var olderSummaries: [ExerciseSummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        return summaries.filter { $0.lastActivityAt < cutoff }
    }

    private var sessionsThisMonth: Int {
        let cal = Calendar.current
        let dates = loggedExercises
            .compactMap { $0.session?.date }
            .filter { cal.isDate($0, equalTo: .now, toGranularity: .month) }
            .map { cal.startOfDay(for: $0) }
        return Set(dates).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    ZStack {
                        ScreenBackground()
                        EmptyStatsState()
                    }
                } else {
                    List {
                        Section {
                            HStack(spacing: 18) {
                                OverviewMetric(value: "\(summaries.count)", label: "EXERCISES")
                                Divider().frame(height: 28)
                                OverviewMetric(value: "\(sessionsThisMonth)", label: "DAYS THIS MONTH")
                                Spacer()
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        if !activeSummaries.isEmpty {
                            Section {
                                ForEach(activeSummaries) { summary in
                                    NavigationLink {
                                        ExerciseProgressView(exerciseName: summary.name)
                                    } label: {
                                        ExerciseStatRow(summary: summary, unit: unitPref.unit)
                                    }
                                }
                            } header: {
                                Text("Active · last 2 weeks")
                            }
                        }

                        if !olderSummaries.isEmpty {
                            Section {
                                ForEach(olderSummaries) { summary in
                                    NavigationLink {
                                        ExerciseProgressView(exerciseName: summary.name)
                                    } label: {
                                        ExerciseStatRow(summary: summary, unit: unitPref.unit)
                                    }
                                }
                            } header: {
                                Text("Older")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Stats")
        }
    }
}

private struct OverviewMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2.bold())
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExerciseStatRow: View {
    let summary: StatsView.ExerciseSummary
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(summary.lastSessionDate.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.latestE1RM.formattedWeight(unit: unit))
                    .font(.subheadline.bold().monospacedDigit())
                Text("e1RM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            TrendBadge(delta: summary.trend, unit: unit)
        }
        .padding(.vertical, 4)
    }
}

private struct TrendBadge: View {
    let delta: Double
    let unit: WeightUnit

    private var color: Color {
        if delta > 0.5 { return .green }
        if delta < -0.5 { return .red }
        return .secondary
    }

    private var icon: String {
        if delta > 0.5 { return "arrow.up.right" }
        if delta < -0.5 { return "arrow.down.right" }
        return "arrow.right"
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption.bold())
            Text(abs(delta).formattedWeight(unit: unit))
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmptyStatsState: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.title2.bold())
            Text("Log some sets and your progress charts will appear here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
    }
}

struct SessionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let topE1RM: Double
    let totalVolume: Double
}

enum ChartRange: String, CaseIterable, Identifiable {
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        case .all: return nil
        }
    }
}

struct ExerciseProgressView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    let exerciseName: String

    @Query private var allLogs: [LoggedExercise]
    @State private var range: ChartRange = .threeMonths

    init(exerciseName: String) {
        self.exerciseName = exerciseName
    }

    private var logs: [LoggedExercise] {
        let key = exerciseName.normalizedExerciseKey
        return allLogs.filter { log in
            log.exerciseName.normalizedExerciseKey == key
                && log.orderedSets.contains { $0.weight > 0 && $0.reps > 0 }
        }
    }

    private var allSessionPoints: [SessionPoint] {
        logs
            .compactMap { log -> SessionPoint? in
                guard let date = log.session?.date else { return nil }
                let sets = log.orderedSets.filter { $0.reps > 0 && $0.weight > 0 }
                guard !sets.isEmpty else { return nil }
                let top = sets.map(\.estimatedOneRepMax).max() ?? 0
                let volume = sets.map(\.volume).reduce(0, +)
                return SessionPoint(date: date, topE1RM: top, totalVolume: volume)
            }
            .sorted { $0.date < $1.date }
    }

    private var sessionPoints: [SessionPoint] {
        guard let days = range.days else { return allSessionPoints }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return allSessionPoints.filter { $0.date >= cutoff }
    }

    private var bestE1RM: Double { sessionPoints.map(\.topE1RM).max() ?? 0 }
    private var bestVolume: Double { sessionPoints.map(\.totalVolume).max() ?? 0 }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if allSessionPoints.isEmpty {
                        Text("No completed sets yet.")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        RangePicker(selection: $range)

                        if sessionPoints.isEmpty {
                            Text("No sessions in this range.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }

                        HighlightRow(
                            items: [
                                .init(value: bestE1RM.formattedWeight(unit: unitPref.unit), label: "BEST e1RM"),
                                .init(value: bestVolume.formattedWeight(unit: unitPref.unit), label: "BEST VOLUME"),
                                .init(value: "\(sessionPoints.count)", label: "SESSIONS")
                            ]
                        )

                        ChartCard(
                            title: "Estimated 1RM",
                            subtitle: "Top set per session (Epley formula)",
                            points: sessionPoints,
                            valueKeyPath: \.topE1RM,
                            color: Theme.accent,
                            unit: unitPref.unit
                        )

                        ChartCard(
                            title: "Total Volume",
                            subtitle: "Sum of weight × reps across all sets",
                            points: sessionPoints,
                            valueKeyPath: \.totalVolume,
                            color: .blue,
                            unit: unitPref.unit
                        )

                        NavigationLink {
                            ExerciseHistoryView(exerciseName: exerciseName)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("View full history")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RangePicker: View {
    @Binding var selection: ChartRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartRange.allCases) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Theme.accent)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

private struct HighlightRow: View {
    struct Item: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }
    let items: [Item]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(item.label)
                        .font(.caption2.bold())
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
            }
        }
    }
}

private struct ChartCard: View {
    let title: String
    let subtitle: String
    let points: [SessionPoint]
    let valueKeyPath: KeyPath<SessionPoint, Double>
    let color: Color
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Chart(points) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value(title, p[keyPath: valueKeyPath])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.35), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", p.date),
                    y: .value(title, p[keyPath: valueKeyPath])
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", p.date),
                    y: .value(title, p[keyPath: valueKeyPath])
                )
                .foregroundStyle(color)
                .symbolSize(40)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .card()
    }
}

