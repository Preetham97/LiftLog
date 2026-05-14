import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject private var unitPref: UnitPreference
    @Query private var allLoggedExercises: [LoggedExercise]
    @State private var othersExpanded: Bool = false

    private var loggedExercises: [LoggedExercise] {
        allLoggedExercises.filter { log in
            log.session?.isCompleted == true
                && log.hasAnyValidSet
                && !log.isSkippedBySession
        }
    }

    struct ExerciseSummary: Identifiable {
        let id: String
        let name: String
        let isBodyweight: Bool
        let latestValue: Double
        let sessionCount: Int
        let trend: Double
        let lastSessionDate: Date
        let lastActivityAt: Date
        let points: [SessionPoint]
    }

    private var summaries: [ExerciseSummary] {
        let grouped = Dictionary(grouping: loggedExercises, by: { $0.exerciseName.normalizedExerciseKey })
        return grouped.compactMap { key, logs in
            // Pick the most recent variant of the name as the display string.
            let mostRecent = logs.max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
            let displayName = mostRecent?.exerciseName ?? key
            let isBW = mostRecent?.effectiveIsBodyweight ?? false

            let dated = logs.compactMap { log -> (Date, Double, Double)? in
                guard let d = log.session?.date else { return nil }
                let valid = log.validSets
                guard !valid.isEmpty else { return nil }
                let topV: Double
                let totalV: Double
                if log.effectiveIsBodyweight {
                    topV = Double(valid.map(\.reps).max() ?? 0)
                    totalV = Double(valid.map(\.reps).reduce(0, +))
                } else {
                    topV = valid.map(\.estimatedOneRepMax).max() ?? 0
                    totalV = valid.map(\.volume).reduce(0, +)
                }
                guard topV > 0 else { return nil }
                return (d, topV, totalV)
            }.sorted { $0.0 < $1.0 }
            guard let last = dated.last else { return nil }
            let prev = dated.dropLast().last?.1 ?? last.1
            let trend = last.1 - prev

            // The most recent valid set across all of this exercise's logs.
            let latestSetAt = logs
                .flatMap { $0.validSets }
                .map(\.completedAt)
                .max() ?? last.0

            let points = dated.map { SessionPoint(date: $0.0, topValue: $0.1, totalValue: $0.2) }

            return ExerciseSummary(
                id: key,
                name: displayName,
                isBodyweight: isBW,
                latestValue: last.1,
                sessionCount: dated.count,
                trend: trend,
                lastSessionDate: last.0,
                lastActivityAt: latestSetAt,
                points: points
            )
        }.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    private var latestSessionExerciseKeys: Set<String> {
        let latestSession = allLoggedExercises
            .compactMap { $0.session }
            .filter { $0.isCompleted }
            .max { $0.date < $1.date }
        guard let s = latestSession else { return [] }
        return Set(
            s.loggedExercises
                .filter { $0.hasAnyValidSet && !$0.isSkippedBySession }
                .map { $0.exerciseName.normalizedExerciseKey }
        )
    }

    private var featuredSummaries: [ExerciseSummary] {
        summaries.filter { latestSessionExerciseKeys.contains($0.id) }
    }

    private var otherSummaries: [ExerciseSummary] {
        summaries.filter { !latestSessionExerciseKeys.contains($0.id) }
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
            ZStack {
                ScreenBackground()
                if summaries.isEmpty {
                    EmptyStatsState()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            HStack(spacing: 18) {
                                OverviewMetric(value: "\(summaries.count)", label: "EXERCISES")
                                Divider().frame(height: 28)
                                OverviewMetric(value: "\(sessionsThisMonth)", label: "DAYS THIS MONTH")
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)

                            if !featuredSummaries.isEmpty {
                                SectionHeader(title: "From your latest session")
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ], spacing: 10) {
                                    ForEach(featuredSummaries) { summary in
                                        NavigationLink {
                                            ExerciseProgressView(exerciseName: summary.name)
                                        } label: {
                                            ExerciseChartCard(summary: summary, unit: unitPref.unit)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if !otherSummaries.isEmpty {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        othersExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("Other exercises".uppercased())
                                            .font(.caption2.bold())
                                            .tracking(0.8)
                                            .foregroundStyle(.secondary)
                                        Text("· \(otherSummaries.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Image(systemName: othersExpanded ? "chevron.up" : "chevron.down")
                                            .font(.caption.bold())
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.top, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if othersExpanded {
                                    VStack(spacing: 0) {
                                        ForEach(Array(otherSummaries.enumerated()), id: \.element.id) { idx, summary in
                                            NavigationLink {
                                                ExerciseProgressView(exerciseName: summary.name)
                                            } label: {
                                                ExerciseStatRow(summary: summary, unit: unitPref.unit)
                                            }
                                            .buttonStyle(.plain)
                                            if idx < otherSummaries.count - 1 {
                                                Divider().padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                                    .transition(.opacity)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
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

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.bold())
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 6)
    }
}

private struct ExerciseChartCard: View {
    let summary: StatsView.ExerciseSummary
    let unit: WeightUnit

    private var trendColor: Color {
        if summary.trend > 0.5 { return .green }
        if summary.trend < -0.5 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(summary.lastSessionDate.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            Chart(summary.points) { p in
                if summary.points.count >= 2 {
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("Top", p.topValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [trendColor.opacity(0.32), trendColor.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Top", p.topValue)
                    )
                    .foregroundStyle(trendColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }

                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Top", p.topValue)
                )
                .foregroundStyle(trendColor)
                .symbolSize(summary.points.count == 1 ? 80 : 24)
            }
            .frame(height: 70)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)

            HStack {
                Spacer()
                TrendBadge(delta: summary.trend, format: .from(summary: summary, unit: unit))
            }
        }
        .card(padding: 12)
    }
}

private struct ExerciseStatRow: View {
    let summary: StatsView.ExerciseSummary
    let unit: WeightUnit

    var body: some View {
        let fmt = MetricFormat.from(summary: summary, unit: unit)
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
            TrendBadge(delta: summary.trend, format: fmt)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}

enum MetricFormat {
    case weight(WeightUnit)
    case reps

    static func from(summary: StatsView.ExerciseSummary, unit: WeightUnit) -> MetricFormat {
        summary.isBodyweight ? .reps : .weight(unit)
    }

    static func from(isBodyweight: Bool, unit: WeightUnit) -> MetricFormat {
        isBodyweight ? .reps : .weight(unit)
    }

    func format(_ value: Double) -> String {
        switch self {
        case .weight(let u): return value.formattedWeight(unit: u)
        case .reps: return "\(Int(value.rounded())) reps"
        }
    }

    var shortLabel: String {
        switch self {
        case .weight: return "e1RM"
        case .reps: return "top reps"
        }
    }
}

struct TrendBadge: View {
    let delta: Double
    let format: MetricFormat

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
            Text(format.format(abs(delta)))
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
    /// e1RM for weighted exercises, max reps in a single set for bodyweight.
    let topValue: Double
    /// Total volume (weight × reps) for weighted, total reps for bodyweight.
    let totalValue: Double
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
                && log.session?.isCompleted == true
                && log.hasAnyValidSet
                && !log.isSkippedBySession
        }
    }

    private var isBodyweight: Bool {
        logs
            .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }?
            .effectiveIsBodyweight ?? false
    }

    private var allSessionPoints: [SessionPoint] {
        logs
            .compactMap { log -> SessionPoint? in
                guard let date = log.session?.date else { return nil }
                let valid = log.validSets
                guard !valid.isEmpty else { return nil }
                let topV: Double
                let totalV: Double
                if log.effectiveIsBodyweight {
                    topV = Double(valid.map(\.reps).max() ?? 0)
                    totalV = Double(valid.map(\.reps).reduce(0, +))
                } else {
                    topV = valid.map(\.estimatedOneRepMax).max() ?? 0
                    totalV = valid.map(\.volume).reduce(0, +)
                }
                return SessionPoint(date: date, topValue: topV, totalValue: totalV)
            }
            .sorted { $0.date < $1.date }
    }

    private var sessionPoints: [SessionPoint] {
        guard let days = range.days else { return allSessionPoints }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return allSessionPoints.filter { $0.date >= cutoff }
    }

    private var bestTop: Double { sessionPoints.map(\.topValue).max() ?? 0 }
    private var bestTotal: Double { sessionPoints.map(\.totalValue).max() ?? 0 }

    private var topFormat: MetricFormat {
        isBodyweight ? .reps : .weight(unitPref.unit)
    }

    private var topTitle: String { isBodyweight ? "Top reps" : "Estimated 1RM" }
    private var topSubtitle: String {
        isBodyweight ? "Best set in each session" : "Top set per session (Epley formula)"
    }
    private var totalTitle: String { isBodyweight ? "Total reps" : "Total Volume" }
    private var totalSubtitle: String {
        isBodyweight ? "Sum of reps across all sets" : "Sum of weight × reps across all sets"
    }
    private var bestTopLabel: String { isBodyweight ? "BEST TOP REPS" : "BEST e1RM" }
    private var bestTotalLabel: String { isBodyweight ? "BEST TOTAL REPS" : "BEST VOLUME" }

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
                                .init(value: topFormat.format(bestTop), label: bestTopLabel),
                                .init(value: topFormat.format(bestTotal), label: bestTotalLabel),
                                .init(value: "\(sessionPoints.count)", label: "SESSIONS")
                            ]
                        )

                        ChartCard(
                            title: topTitle,
                            subtitle: topSubtitle,
                            points: sessionPoints,
                            valueKeyPath: \.topValue,
                            color: Theme.accent,
                            format: topFormat
                        )

                        ChartCard(
                            title: totalTitle,
                            subtitle: totalSubtitle,
                            points: sessionPoints,
                            valueKeyPath: \.totalValue,
                            color: .blue,
                            format: topFormat
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
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
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
    let format: MetricFormat

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

