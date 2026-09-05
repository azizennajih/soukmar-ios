import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = ForgotPasswordViewModel()
    @ObservedObject private var i18n = I18nRepository.shared
    var onBackToLogin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            SoukMarLogo().padding(.top, 32)

            VStack(spacing: 4) {
                Text(i18n.t("auth.forgot_title")).font(.title2.bold())
                Text(i18n.t("auth.forgot_sub"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.sent {
                SuccessBanner(message: i18n.t("auth.forgot_sent", ["email": viewModel.email]))
                Button(i18n.t("auth.back_to_login")) { onBackToLogin() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .controlSize(.large)
            } else {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }
                TextField(i18n.t("auth.email"), text: $viewModel.email)
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
                        Text(i18n.t("auth.forgot_btn")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .controlSize(.large)
                .disabled(viewModel.loading)

                Button(i18n.t("auth.back_to_login"), action: onBackToLogin)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    NavigationStack { ForgotPasswordView(onBackToLogin: {}) }
}
