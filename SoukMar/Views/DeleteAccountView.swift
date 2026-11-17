import SwiftUI

/// Mirrors soukmar-android's DeleteAccountScreen — warning box, password
/// re-entry, explicit confirmation checkbox, destructive submit button.
struct DeleteAccountView: View {
    var onLoggedOut: () -> Void

    @StateObject private var viewModel = DeleteAccountViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.deleted {
                    SuccessBanner(message: i18n.t("delete_account.success"))
                } else {
                    Text(i18n.t("delete_account.warning"))
                        .font(.subheadline)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 14) {
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error)
                        }

                        PasswordField(placeholder: i18n.t("delete_account.password_label"), text: $viewModel.password)

                        Button {
                            viewModel.confirmed.toggle()
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: viewModel.confirmed ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(viewModel.confirmed ? .red : Color(.systemGray3))
                                Text(i18n.t("delete_account.confirm_checkbox"))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.submit(onLoggedOut: onLoggedOut)
                        } label: {
                            if viewModel.submitting {
                                ProgressView().tint(.white).frame(maxWidth: .infinity)
                            } else {
                                Text(i18n.t("delete_account.submit_btn")).fontWeight(.bold).frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(!viewModel.canSubmit)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .navigationTitle(i18n.t("delete_account.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
