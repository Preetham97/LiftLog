import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    @Query(filter: #Predicate<LoggedExercise> { $0.isCompleted }) private var loggedExercises: [LoggedExercise]

    struct ExerciseSummary: Identifiable {
        let id: String
        let name: String
        let latestE1RM: Double
        let sessionCount: Int
        let trend: Double
        let lastSessionDate: Date
    }

    private var summaries: [ExerciseSummary] {
        let grouped = Dictionary(grouping: loggedExercises, by: \.exerciseName)
        return grouped.compactMap { name, logs in
            let dated = logs.compactMap { log -> (Date, Double)? in
                guard let d = log.session?.date else { return nil }
                let top = log.orderedSets.map(\.estimatedOneRepMax).max() ?? 0
                guard top > 0 else { return nil }
                return (d, top)
            }.sorted { $0.0 < $1.0 }
            guard let last = dated.last else { return nil }
            let prev = dated.dropLast().last?.1 ?? last.1
            let trend = last.1 - prev
            return ExerciseSummary(
                id: name,
                name: name,
                latestE1RM: last.1,
                sessionCount: dated.count,
                trend: trend,
                lastSessionDate: last.0
            )
        }.sorted { $0.lastSessionDate > $1.lastSessionDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                if summaries.isEmpty {
                    EmptyStatsState()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(summaries) { summary in
                                NavigationLink {
                                    ExerciseProgressView(exerciseName: summary.name)
                                } label: {
                                    StatSummaryCard(summary: summary, unit: unitPref.unit)
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
            .navigationTitle("Stats")
        }
    }
}

private struct StatSummaryCard: View {
    let summary: StatsView.ExerciseSummary
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("\(summary.sessionCount) session\(summary.sessionCount == 1 ? "" : "s")")
                    Text("•").foregroundStyle(.tertiary)
                    Text(summary.lastSessionDate.formatted(.relative(presentation: .named)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(summary.latestE1RM.formattedWeight(unit: unit))
                    .font(.title3.bold().monospacedDigit())
                Text("e1RM")
                    .font(.caption2.bold())
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            TrendBadge(delta: summary.trend, unit: unit)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .card()
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
                .foregroundStyle(Theme.accent)
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

struct ExerciseProgressView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    let exerciseName: String

    @Query private var logs: [LoggedExercise]

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        let name = exerciseName
        self._logs = Query(
            filter: #Predicate<LoggedExercise> { $0.exerciseName == name && $0.isCompleted }
        )
    }

    private var sessionPoints: [SessionPoint] {
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

    private var bestE1RM: Double { sessionPoints.map(\.topE1RM).max() ?? 0 }
    private var bestVolume: Double { sessionPoints.map(\.totalVolume).max() ?? 0 }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if sessionPoints.isEmpty {
                        Text("No completed sets yet.")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
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

                        RecentSessionsCard(points: sessionPoints, unit: unitPref.unit)

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

private struct RecentSessionsCard: View {
    let points: [SessionPoint]
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent sessions")
                .font(.headline)
            VStack(spacing: 0) {
                let recent = Array(points.suffix(8).reversed())
                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, p in
                    HStack {
                        Text(p.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.callout)
                        Spacer()
                        Text(p.topE1RM.formattedWeight(unit: unit))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    if idx < recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .card()
    }
}
