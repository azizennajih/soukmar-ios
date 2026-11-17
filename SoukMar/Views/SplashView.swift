import SwiftUI

/// Start screen: brand red over the whole screen, white SouqMar24 wordmark in the middle. Same colour and same size (240 pt) as the
/// system launch screen (UILaunchScreen in project.yml: LaunchBackground + LaunchLogo from Assets.xcassets), so the hand-over is seamless.
/// Shown for a short moment on every fresh app start by SoukMarApp.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .accessibilityLabel("SouqMar24")
        }
    }
}
