import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var unitPref: UnitPreference

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("UNITS")
                                .font(.caption2.bold())
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(WeightUnit.allCases) { u in
                                    Button {
                                        unitPref.unit = u
                                    } label: {
                                        Text(u.label.uppercased())
                                            .font(.subheadline.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                unitPref.unit == u ? Theme.accent : Color(.tertiarySystemGroupedBackground)
                                            )
                                            .foregroundStyle(unitPref.unit == u ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.pillCorner, style: .continuous))
                                    }
                                }
                            }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ABOUT")
                                .font(.caption2.bold())
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("LiftLog")
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text("v0.1.0")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .card()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
