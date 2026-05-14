import SwiftUI

/// Designed image-friendly card for sharing a single completed session.
/// Always rendered at a fixed width via `ImageRenderer` — pure VStack
/// layout so it composites cleanly regardless of dynamic type or
/// device chrome.
struct ShareCardView: View {
    struct ExerciseSummary: Identifiable {
        let id: String  // normalized key
        let name: String
        let isBodyweight: Bool
        let topSetText: String     // e.g. "100 lbs × 8" or "25 reps"
        let metricLabel: String    // "e1RM" or "top reps"
        let metricValue: String    // e.g. "120 lbs" or "25 reps"
        let trend: Double
        let format: MetricFormat
    }

    let date: Date
    let routineName: String
    let dayName: String
    let exercises: [ExerciseSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("LIFTLOG")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(dayName)
                        .font(.system(size: 28, weight: .bold))
                    if !routineName.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(routineName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Exercises
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, ex in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ex.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(ex.topSetText)
                                .font(.system(size: 13, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(ex.metricValue)
                                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(ex.metricLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(.tertiary)
                            }
                            TrendBadge(delta: ex.trend, format: ex.format)
                        }
                    }
                    .padding(.vertical, 12)
                    if idx < exercises.count - 1 {
                        Divider()
                    }
                }
            }

            // Footer
            HStack {
                Text("\(exercises.count) lift\(exercises.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Track every rep, push every session.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}
