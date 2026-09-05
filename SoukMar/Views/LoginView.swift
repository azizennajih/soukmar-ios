import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    var onLoginSuccess: () -> Void
    var onNavigateToRegister: () -> Void = {}
    var onNavigateToForgotPassword: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SoukMarLogo()
                    .padding(.top, 32)

                VStack(spacing: 4) {
                    Text("Bon retour !")
                        .font(.title2.bold())
                    Text("Connectez-vous à votre compte")
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }

                if let unverified = viewModel.unverifiedEmail {
                    if viewModel.resendOk {
                        SuccessBanner(message: "Email renvoyé !")
                    } else {
                        Button(viewModel.resendLoading ? "Envoi..." : "Renvoyer l'email de confirmation") {
                            viewModel.resendVerification()
                        }
                        .disabled(viewModel.resendLoading)
                    }
                    Text(unverified).font(.caption).foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Mot de passe", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Spacer()
                    Button("Mot de passe oublié ?", action: onNavigateToForgotPassword)
                        .font(.footnote)
                }

                Button {
                    viewModel.submit(onSuccess: onLoginSuccess)
                } label: {
                    if viewModel.loading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Se connecter").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .controlSize(.large)
                .disabled(viewModel.loading)

                HStack(spacing: 4) {
                    Text("Pas encore de compte ?").foregroundStyle(.secondary)
                    Button("S'inscrire gratuitement", action: onNavigateToRegister)
                        .fontWeight(.bold)
                }
                .font(.footnote)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {})
}
