import SwiftUI

/// Start screen: white ground, the red logo tile exactly in the middle, same artwork, size (96 pt) and place as the system
/// launch screen (UILaunchScreen in project.yml: LaunchBackground + LaunchLogo from Assets.xcassets), so the hand-over is
/// seamless. The wordmark fades in below it. No progress indicator. Shown for a short moment on every fresh app start by SoukMarApp.
struct SplashView: View {
    @State private var wordmarkShown = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            SoukMarMark(size: 96)
            HStack(spacing: 0) {
                Text("SouqMar").foregroundStyle(Color.soukmarInk)
                Text("24").foregroundStyle(Color.soukmarPrimary)
            }
            .font(.system(size: 28, weight: .black))
            // The wordmark is a brand: always left to right.
            .environment(\.layoutDirection, .leftToRight)
            .opacity(wordmarkShown ? 1 : 0)
            .offset(y: wordmarkShown ? 84 : 76)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SouqMar24")
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.1)) { wordmarkShown = true }
        }
    }
}
