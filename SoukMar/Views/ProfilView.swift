import SwiftUI
import PhotosUI

/// Mirrors soukmar-android's ProfilScreen — avatar upload, editable
/// name/phone/city, change-password form.
struct ProfilView: View {
    @StateObject private var viewModel = ProfilViewModel()
    @State private var avatarItem: PhotosPickerItem?
    @State private var idPhotoItem: PhotosPickerItem?
    @State private var selfiePhotoItem: PhotosPickerItem?
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.loadError || viewModel.profile == nil {
                Text("Impossible de charger le profil.").foregroundStyle(.secondary)
            } else if let profile = viewModel.profile {
                content(for: profile)
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.pickAvatar(data: data)
                }
                avatarItem = nil
            }
        }
        .onChange(of: idPhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.pickIdImage(data: data)
                }
            }
        }
        .onChange(of: selfiePhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.pickSelfieImage(data: data)
                }
            }
        }
    }

    @ViewBuilder
    private func content(for profile: UserDto) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                identityCard(for: profile)
                editForm
                idVerificationCard
                passwordForm
            }
            .padding(16)
        }
    }

    /// Free KYC-lite: ID photo + selfie, reviewed manually by an admin (see
    /// AdminView's "Vérifications" tab). Four states, mirrors the web's
    /// profil.component.html card: not yet submitted (form) / pending
    /// (status only) / approved (status only) / rejected (note + form again,
    /// resubmission allowed).
    @ViewBuilder
    private var idVerificationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(i18n.t("profil.id_verification_title")).font(.headline)
            Text(i18n.t("profil.id_verification_desc"))
                .font(.caption)
                .foregroundStyle(.secondary)

            switch viewModel.idVerificationStatus {
            case "APPROVED":
                Label(i18n.t("profil.id_verification_approved"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            case "PENDING":
                Label(i18n.t("profil.id_verification_pending"), systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.soukmarGold)
            default:
                if viewModel.idVerificationStatus == "REJECTED" {
                    Label(i18n.t("profil.id_verification_rejected"), systemImage: "xmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    if let note = viewModel.idVerificationNote, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }

                idPhotoPicker(
                    label: i18n.t("profil.id_verification_id_label"),
                    item: $idPhotoItem,
                    hasData: viewModel.idImageData != nil
                )
                idPhotoPicker(
                    label: i18n.t("profil.id_verification_selfie_label"),
                    item: $selfiePhotoItem,
                    hasData: viewModel.selfieImageData != nil
                )

                if let success = viewModel.idVerificationMessage {
                    SuccessBanner(message: success)
                }
                if let error = viewModel.idVerificationErrorMessage {
                    ErrorBanner(message: error)
                }

                Button {
                    viewModel.submitIdVerification()
                } label: {
                    if viewModel.idVerificationSubmitting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text(i18n.t("profil.id_verification_submit")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .disabled(viewModel.idVerificationSubmitting || viewModel.idImageData == nil || viewModel.selfieImageData == nil)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func idPhotoPicker(label: String, item: Binding<PhotosPickerItem?>, hasData: Bool) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            HStack {
                Image(systemName: hasData ? "checkmark.circle.fill" : "photo.badge.plus")
                    .foregroundStyle(hasData ? .green : Color.soukmarPrimary)
                Text(label).font(.subheadline).foregroundStyle(.primary)
                Spacer()
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func identityCard(for profile: UserDto) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(Color.soukmarPrimary).frame(width: 84, height: 84)
                    if let imageUrl = profile.image, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Text(profile.name.prefix(1).uppercased()).foregroundStyle(.white).font(.title.bold())
                            }
                        }
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                    } else {
                        Text(profile.name.prefix(1).uppercased()).foregroundStyle(.white).font(.title.bold())
                    }
                    if viewModel.uploadingImage {
                        Circle().fill(.black.opacity(0.4)).frame(width: 84, height: 84)
                        ProgressView().tint(.white)
                    }
                }

                PhotosPicker(selection: $avatarItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.soukmarPrimary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
                .disabled(viewModel.uploadingImage)
            }
            Text(profile.name).font(.headline)
            Text(profile.email).font(.caption).foregroundStyle(.secondary)
            if profile.role == "ADMIN" {
                Text(i18n.t("profil.role_admin"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.soukmarGoldLight)
                    .foregroundStyle(Color.soukmarGold)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(i18n.t("profil.edit_title")).font(.headline)

            if let success = viewModel.successMessage {
                SuccessBanner(message: success)
            }
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            TextField(i18n.t("profil.name"), text: $viewModel.name).textFieldStyle(.roundedBorder)
            TextField("Email", text: .constant(viewModel.profile?.email ?? ""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)
                .foregroundStyle(.secondary)
            PhoneInputField(value: $viewModel.phone)
            if !(viewModel.profile?.phone ?? "").isEmpty {
                PhoneVerificationRow(viewModel: viewModel)
            }
            TextField(i18n.t("profil.city"), text: $viewModel.city).textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text(i18n.t("auth.account_type")).font(.subheadline.weight(.medium))
                AccountTypeSelector(
                    selected: $viewModel.accountType,
                    options: [
                        ("PRIVATE", i18n.t("auth.account_type_private")),
                        ("BUSINESS", i18n.t("auth.account_type_business")),
                    ]
                )
            }

            Button {
                viewModel.saveProfile()
            } label: {
                if viewModel.saving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text(i18n.t("profil.save")).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.soukmarPrimary)
            .disabled(viewModel.saving)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var passwordForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(i18n.t("profil.change_password_title")).font(.headline)

            if let success = viewModel.pwSuccessMessage {
                SuccessBanner(message: success)
            }
            if let error = viewModel.pwErrorMessage {
                ErrorBanner(message: error)
            }

            PasswordField(placeholder: i18n.t("profil.current_password"), text: $viewModel.currentPassword)
            PasswordField(placeholder: i18n.t("profil.new_password"), text: $viewModel.newPassword)
            PasswordField(placeholder: i18n.t("profil.confirm_password"), text: $viewModel.confirmPassword)

            Button {
                viewModel.changePassword()
            } label: {
                if viewModel.pwSaving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text(i18n.t("profil.change_password_btn")).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.soukmarPrimary)
            .disabled(viewModel.pwSaving)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct PhoneVerificationRow: View {
    @ObservedObject var viewModel: ProfilViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if viewModel.profile?.phoneVerified == true {
                Label(i18n.t("profil.phone_verified"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if !viewModel.phoneCodeSent {
                HStack {
                    Text(i18n.t("profil.phone_not_verified"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(viewModel.phoneSendingCode ? i18n.t("profil.phone_sending") : i18n.t("profil.phone_verify_btn")) {
                        viewModel.sendPhoneCode()
                    }
                    .font(.caption)
                    .disabled(viewModel.phoneSendingCode)
                }
            } else {
                Text(i18n.t("profil.phone_code_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("", text: $viewModel.phoneCode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button(viewModel.phoneVerifying ? i18n.t("profil.phone_verifying") : i18n.t("profil.phone_confirm_btn")) {
                        viewModel.verifyPhoneCode()
                    }
                    .font(.caption)
                    .disabled(viewModel.phoneVerifying || viewModel.phoneCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button(i18n.t("profil.phone_resend")) {
                    viewModel.sendPhoneCode()
                }
                .font(.caption)
                .disabled(viewModel.phoneSendingCode)
            }
            if let message = viewModel.phoneMessage {
                SuccessBanner(message: message)
            }
            if let error = viewModel.phoneErrorMessage {
                ErrorBanner(message: error)
            }
        }
    }
}

#Preview {
    NavigationStack { ProfilView() }
}
