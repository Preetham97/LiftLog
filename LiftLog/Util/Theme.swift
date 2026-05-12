import SwiftUI

enum Theme {
    static let accent = Color(red: 0.95, green: 0.45, blue: 0.20)
    static let accentSoft = Color(red: 0.95, green: 0.45, blue: 0.20).opacity(0.12)
    static let cardCorner: CGFloat = 18
    static let pillCorner: CGFloat = 12
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

struct PillLabel: View {
    let text: String
    var color: Color = Theme.accent
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ScreenBackground: View {
    var body: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }
}
