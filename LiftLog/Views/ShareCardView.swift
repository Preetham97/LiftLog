import SwiftUI

/// Designed image-friendly card for sharing a single completed session.
/// Always rendered at a fixed width via `ImageRenderer`.
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
            header

            VStack(alignment: .leading, spacing: 4) {
                if !routineName.isEmpty {
                    Text(routineName.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.8)
                        .foregroundStyle(Theme.accent)
                }
                Text(dayName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
            }

            exerciseList

            footer
        }
        .padding(28)
        .frame(width: 600)
        .background(
            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [Theme.accent.opacity(0.10), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("LiftLog")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Workout summary")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(date.formatted(.dateTime.month().day().year()))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var exerciseList: some View {
        VStack(spacing: 10) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, ex in
                HStack(alignment: .center, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .frame(width: 22, height: 22)
                        .background(Theme.accent.opacity(0.14))
                        .foregroundStyle(Theme.accent)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(ex.topSetText)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(ex.metricValue)
                                .font(.system(size: 13, weight: .bold).monospacedDigit())
                                .foregroundStyle(.primary)
                            Text(ex.metricLabel)
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(.tertiary)
                        }
                        TrendBadge(delta: ex.trend, format: ex.format)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .opacity(0.7)
            Text("Tracked with LiftLog · \(exercises.count) lift\(exercises.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
