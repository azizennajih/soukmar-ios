import SwiftUI

/// Minimal placeholder proving the post-login flow end to end — mirrors the
/// very first slice of soukmar-android's HomeScreen (greeting + logout).
/// Real feature screens (browse/search, listing detail, etc.) land in
/// later iOS phases, same phased approach used for the Android app.
struct HomeView: View {
    @State private var user: UserDto? = TokenStore.shared.cachedUser
    var onLoggedOut: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let user {
                    Text("Bonjour, \(user.name) 👋")
                        .font(.title3.bold())
                }
                Text("SoukMar iOS — Phase 14 en cours de construction.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
            .navigationTitle("SoukMar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Se déconnecter") {
                        AuthRepository.shared.logout()
                        onLoggedOut()
                    }
                }
            }
            .task {
                if let refreshed = await AuthRepository.shared.me() {
                    user = refreshed
                }
            }
        }
    }
}

#Preview {
    HomeView(onLoggedOut: {})
}
