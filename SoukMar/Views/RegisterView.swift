import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    var onNavigateToLogin: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SoukMarLogo().padding(.top, 32)

                if viewModel.emailSent {
                    VStack(spacing: 4) {
                        Text("Vérifiez votre email").font(.title2.bold())
                    }
                    Text("Un lien de confirmation a été envoyé à \(viewModel.registeredEmail ?? ""). Cliquez sur le lien dans l'email pour activer votre compte.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if viewModel.resendOk {
                        SuccessBanner(message: "Email renvoyé !")
                    } else {
                        Button(viewModel.resendLoading ? "Envoi..." : "Renvoyer l'email") {
                            viewModel.resend()
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.resendLoading)
                    }

                    Button("Retour à la connexion", action: onNavigateToLogin)
                        .tint(Color.soukmarPrimary)
                } else {
                    VStack(spacing: 4) {
                        Text("Créer un compte").font(.title2.bold())
                        Text("Rejoignez des milliers d'acheteurs et vendeurs")
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }

                    VStack(spacing: 12) {
                        TextField("Nom complet", text: $viewModel.name)
                            .textFieldStyle(.roundedBorder)
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                        TextField("Téléphone", text: $viewModel.phone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                        TextField("Ville", text: $viewModel.city)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Mot de passe", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Confirmer le mot de passe", text: $viewModel.confirmPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        viewModel.submit()
                    } label: {
                        if viewModel.loading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Créer mon compte").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .controlSize(.large)
                    .disabled(viewModel.loading)

                    HStack(spacing: 4) {
                        Text("Déjà un compte ?").foregroundStyle(.secondary)
                        Button("Se connecter", action: onNavigateToLogin).fontWeight(.bold)
                    }
                    .font(.footnote)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(viewModel.emailSent)
    }
}

#Preview {
    NavigationStack { RegisterView(onNavigateToLogin: {}) }
}
