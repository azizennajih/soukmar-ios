import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @ObservedObject private var i18n = I18nRepository.shared
    var onLoginSuccess: () -> Void
    var onNavigateToRegister: () -> Void = {}
    var onNavigateToForgotPassword: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SoukMarLogo()
                    .padding(.top, 32)

                LanguageSwitcher()

                VStack(spacing: 4) {
                    Text(i18n.t("auth.login_title"))
                        .font(.title2.bold())
                    Text(i18n.t("auth.login_sub"))
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }

                if let unverified = viewModel.unverifiedEmail {
                    if viewModel.resendOk {
                        SuccessBanner(message: i18n.t("auth.verify_resend_ok"))
                    } else {
                        Button(viewModel.resendLoading ? "…" : i18n.t("auth.unverified_resend")) {
                            viewModel.resendVerification()
                        }
                        .disabled(viewModel.resendLoading)
                    }
                    Text(unverified).font(.caption).foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField(i18n.t("auth.email"), text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField(i18n.t("auth.password"), text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Spacer()
                    Button(i18n.t("auth.forgot"), action: onNavigateToForgotPassword)
                        .font(.footnote)
                }

                Button {
                    viewModel.submit(onSuccess: onLoginSuccess)
                } label: {
                    if viewModel.loading {
                        ProgressView().tint(.white)
                    } else {
                        Text(i18n.t("auth.login_btn")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .controlSize(.large)
                .disabled(viewModel.loading)

                HStack(spacing: 4) {
                    Text(i18n.t("auth.no_account")).foregroundStyle(.secondary)
                    Button(i18n.t("auth.register_link"), action: onNavigateToRegister)
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
