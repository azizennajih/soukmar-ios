import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @ObservedObject private var i18n = I18nRepository.shared
    var onNavigateToLogin: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SoukMarLogo().padding(.top, 32)

                if viewModel.emailSent {
                    VStack(spacing: 4) {
                        Text(i18n.t("auth.verify_email_title")).font(.title2.bold())
                    }
                    Text("\(i18n.t("auth.verify_email_sub")) \(viewModel.registeredEmail ?? ""). \(i18n.t("auth.verify_email_hint"))")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if viewModel.resendOk {
                        SuccessBanner(message: i18n.t("auth.verify_resend_ok"))
                    } else {
                        Button(viewModel.resendLoading ? "…" : i18n.t("auth.verify_resend")) {
                            viewModel.resend()
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.resendLoading)
                    }

                    Button(i18n.t("auth.back_to_login"), action: onNavigateToLogin)
                        .tint(Color.soukmarPrimary)
                } else {
                    VStack(spacing: 4) {
                        Text(i18n.t("auth.register_title")).font(.title2.bold())
                        Text(i18n.t("auth.register_sub"))
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }

                    VStack(spacing: 12) {
                        TextField(i18n.t("auth.name"), text: $viewModel.name)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("auth.email"), text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                        TextField(i18n.t("auth.phone"), text: $viewModel.phone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                        TextField(i18n.t("auth.city"), text: $viewModel.city)
                            .textFieldStyle(.roundedBorder)
                        SecureField(i18n.t("auth.password"), text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                        SecureField(i18n.t("auth.reset_confirm_password"), text: $viewModel.confirmPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        viewModel.submit()
                    } label: {
                        if viewModel.loading {
                            ProgressView().tint(.white)
                        } else {
                            Text(i18n.t("auth.register_btn")).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .controlSize(.large)
                    .disabled(viewModel.loading)

                    HStack(spacing: 4) {
                        Text(i18n.t("auth.has_account")).foregroundStyle(.secondary)
                        Button(i18n.t("auth.login_link"), action: onNavigateToLogin).fontWeight(.bold)
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
