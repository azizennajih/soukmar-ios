import SwiftUI
import PhotosUI

/// Mirrors soukmar-android's ProfilScreen — avatar upload, editable
/// name/phone/city, change-password form.
struct ProfilView: View {
    @StateObject private var viewModel = ProfilViewModel()
    @State private var avatarItem: PhotosPickerItem?

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
                Text("🛡️ Admin")
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
            Text("Modifier le profil").font(.headline)

            if let success = viewModel.successMessage {
                SuccessBanner(message: success)
            }
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            TextField("Nom", text: $viewModel.name).textFieldStyle(.roundedBorder)
            TextField("Email", text: .constant(viewModel.profile?.email ?? ""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)
                .foregroundStyle(.secondary)
            TextField("Téléphone", text: $viewModel.phone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
            TextField("Ville", text: $viewModel.city).textFieldStyle(.roundedBorder)

            Button {
                viewModel.saveProfile()
            } label: {
                if viewModel.saving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Enregistrer").frame(maxWidth: .infinity)
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
            Text("Changer le mot de passe").font(.headline)

            if let success = viewModel.pwSuccessMessage {
                SuccessBanner(message: success)
            }
            if let error = viewModel.pwErrorMessage {
                ErrorBanner(message: error)
            }

            SecureField("Mot de passe actuel", text: $viewModel.currentPassword).textFieldStyle(.roundedBorder)
            SecureField("Nouveau mot de passe", text: $viewModel.newPassword).textFieldStyle(.roundedBorder)
            SecureField("Confirmer le nouveau mot de passe", text: $viewModel.confirmPassword).textFieldStyle(.roundedBorder)

            Button {
                viewModel.changePassword()
            } label: {
                if viewModel.pwSaving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Modifier le mot de passe").frame(maxWidth: .infinity)
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
