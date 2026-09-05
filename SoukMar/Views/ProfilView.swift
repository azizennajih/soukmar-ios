import SwiftUI
import PhotosUI

/// Mirrors soukmar-android's ProfilScreen — avatar upload, editable
/// name/phone/city, change-password form.
struct ProfilView: View {
    @StateObject private var viewModel = ProfilViewModel()
    @State private var avatarItem: PhotosPickerItem?
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
    }

    @ViewBuilder
    private func content(for profile: UserDto) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                identityCard(for: profile)
                editForm
                passwordForm
            }
            .padding(16)
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
            TextField(i18n.t("profil.phone"), text: $viewModel.phone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
            TextField(i18n.t("profil.city"), text: $viewModel.city).textFieldStyle(.roundedBorder)

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

            SecureField(i18n.t("profil.current_password"), text: $viewModel.currentPassword).textFieldStyle(.roundedBorder)
            SecureField(i18n.t("profil.new_password"), text: $viewModel.newPassword).textFieldStyle(.roundedBorder)
            SecureField(i18n.t("profil.confirm_password"), text: $viewModel.confirmPassword).textFieldStyle(.roundedBorder)

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

#Preview {
    NavigationStack { ProfilView() }
}
