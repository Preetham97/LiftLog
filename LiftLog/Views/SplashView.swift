import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.88
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 8
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.086, green: 0.086, blue: 0.094)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("Logo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 4) {
                    Text("LiftLog")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("track every rep, push every session")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.18)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
        }
    }
}
