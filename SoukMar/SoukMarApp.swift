import SwiftUI

@main
struct SoukMarApp: App {
    @ObservedObject private var i18n = I18nRepository.shared
    /// Brand moment: the logo stays visible for a short while on every fresh start, then fades out.
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    // Mirrors the web's document.dir = 'rtl' / Android's
                    // LocalLayoutDirection override: SwiftUI mirrors the whole
                    // subtree (nav bars, alignment, etc.) automatically.
                    .environment(\.layoutDirection, i18n.isRtl ? .rightToLeft : .leftToRight)
                    // One brand appearance for the whole app: red as the control colour, fully round buttons.
                    .tint(Color.soukmarPrimary)
                    .buttonBorderShape(.capsule)
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            // The brand is defined on a white ground; a dark variant needs its own palette and is not part of this design yet.
            .preferredColorScheme(.light)
            .task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
            }
        }
    }
}
