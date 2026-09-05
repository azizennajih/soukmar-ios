import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = ForgotPasswordViewModel()
    var onBackToLogin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            SoukMarLogo().padding(.top, 32)

            VStack(spacing: 4) {
                Text("Mot de passe oublié ?").font(.title2.bold())
                Text("Entrez votre email, nous vous enverrons un lien de réinitialisation.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.sent {
                SuccessBanner(message: "Si un compte existe pour \(viewModel.email), un email avec un lien de réinitialisation vient d'être envoyé.")
                Button("Retour à la connexion") { onBackToLogin() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .controlSize(.large)
            } else {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                Button {
                    viewModel.submit()
                } label: {
                    if viewModel.loading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Envoyer le lien").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .controlSize(.large)
                .disabled(viewModel.loading)

                Button("Retour à la connexion", action: onBackToLogin)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    NavigationStack { ForgotPasswordView(onBackToLogin: {}) }
}
