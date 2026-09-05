import SwiftUI

@main
struct SoukMarApp: App {
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                // Mirrors the web's document.dir = 'rtl' / Android's
                // LocalLayoutDirection override: SwiftUI mirrors the whole
                // subtree (nav bars, alignment, etc.) automatically.
                .environment(\.layoutDirection, i18n.isRtl ? .rightToLeft : .leftToRight)
        }
    }
}
