import SwiftUI

/// Mirrors MainActivity's startDestination logic: pick Login vs. Home based
/// on whether a session token is already stored, then let each screen own
/// its own navigation from there.
struct RootView: View {
    @State private var isLoggedIn = TokenStore.shared.isLoggedIn

    var body: some View {
        if isLoggedIn {
            HomeView(onLoggedOut: { isLoggedIn = false })
        } else {
            NavigationStack {
                LoginView(
                    onLoginSuccess: { isLoggedIn = true },
                    onNavigateToRegister: {},
                    onNavigateToForgotPassword: {}
                )
            }
        }
    }
}

#Preview {
    RootView()
}
