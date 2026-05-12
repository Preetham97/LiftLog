import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var unitPref: UnitPreference

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        SettingsCard(title: "APPEARANCE") {
                            SegmentedSelector(
                                selection: Binding(
                                    get: { unitPref.theme },
                                    set: { unitPref.theme = $0 }
                                ),
                                options: AppTheme.allCases
                            ) { theme in
                                VStack(spacing: 4) {
                                    Image(systemName: theme.icon)
                                        .font(.subheadline)
                                    Text(theme.label)
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }

                        SettingsCard(title: "WEIGHT UNITS") {
                            SegmentedSelector(
                                selection: Binding(
                                    get: { unitPref.unit },
                                    set: { unitPref.unit = $0 }
                                ),
                                options: WeightUnit.allCases
                            ) { unit in
                                Text(unit.label.uppercased())
                                    .font(.subheadline.weight(.semibold))
                                    .tracking(0.8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
        .card()
    }
}

private struct SegmentedSelector<Option: Hashable & Identifiable, Label: View>: View {
    @Binding var selection: Option
    let options: [Option]
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        selection = option
                    }
                } label: {
                    label(option)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.accent)
                                        .matchedGeometryEffect(id: "selectorPill", in: namespace)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    @Namespace private var namespace
}
