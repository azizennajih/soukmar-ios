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
            AuthFlowView(onLoginSuccess: { isLoggedIn = true })
        }
    }
}

/// Owns the push-navigation stack between Login → Register / Login →
/// Forgot-password, mirroring the Android nav graph's LOGIN/REGISTER/
/// FORGOT_PASSWORD routes (minus reset-password, which needs a deep-linked
/// token from an email and isn't wired up yet).
private struct AuthFlowView: View {
    var onLoginSuccess: () -> Void

    private enum Route: Hashable {
        case register
        case forgotPassword
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(
                onLoginSuccess: onLoginSuccess,
                onNavigateToRegister: { path.append(.register) },
                onNavigateToForgotPassword: { path.append(.forgotPassword) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .register:
                    RegisterView(onNavigateToLogin: { path.removeAll() })
                case .forgotPassword:
                    ForgotPasswordView(onBackToLogin: { path.removeAll() })
                }
            }
        }
    }
}

#Preview {
    RootView()
}
