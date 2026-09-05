import Foundation

/// Mirrors soukmar-android's ProfilViewModel.
@MainActor
final class ProfilViewModel: ObservableObject {
    @Published private(set) var profile: UserDto?
    @Published private(set) var loading = true
    @Published private(set) var loadError = false

    @Published var name = ""
    @Published var phone = ""
    @Published var city = ""
    @Published private(set) var saving = false
    @Published private(set) var successMessage: String?
    @Published private(set) var errorMessage: String?

    @Published private(set) var uploadingImage = false

    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published private(set) var pwSaving = false
    @Published private(set) var pwSuccessMessage: String?
    @Published private(set) var pwErrorMessage: String?

    private let authRepository = AuthRepository.shared
    private let uploadRepository = UploadRepository.shared

    func load() {
        Task {
            loading = true
            loadError = false
            if let user = await authRepository.me() {
                profile = user
                name = user.name
                phone = user.phone ?? ""
                city = user.city ?? ""
            } else {
                loadError = true
            }
            loading = false
        }
    }

    func saveProfile() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Le nom est requis."
            return
        }
        guard !saving else { return }
        saving = true
        successMessage = nil
        errorMessage = nil
        Task {
            let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
            switch await authRepository.updateProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                city: trimmedCity.isEmpty ? nil : trimmedCity
            ) {
            case .success(let user):
                profile = user
                successMessage = "Profil mis à jour."
            case .failure(let error):
                errorMessage = Self.message(for: error)
            }
            saving = false
        }
    }

    func pickAvatar(data: Data) {
        guard !uploadingImage else { return }
        uploadingImage = true
        errorMessage = nil
        Task {
            switch await uploadRepository.uploadImages([(data: data, filename: "avatar.jpg", mimeType: "image/jpeg")]) {
            case .success(let urls):
                if let url = urls.first {
                    switch await authRepository.updateProfileImage(url: url) {
                    case .success(let user):
                        profile = user
                        successMessage = "Photo de profil mise à jour."
                    case .failure(let error):
                        errorMessage = Self.message(for: error)
                    }
                }
            case .failure:
                errorMessage = "Erreur lors du téléchargement de la photo."
            }
            uploadingImage = false
        }
    }

    func changePassword() {
        pwSuccessMessage = nil
        pwErrorMessage = nil
        guard newPassword.count >= 6 else {
            pwErrorMessage = "Le mot de passe doit contenir au moins 6 caractères."
            return
        }
        guard newPassword == confirmPassword else {
            pwErrorMessage = "Les mots de passe ne correspondent pas."
            return
        }
        guard !pwSaving else { return }
        pwSaving = true
        Task {
            switch await authRepository.changePassword(currentPassword: currentPassword, newPassword: newPassword) {
            case .success:
                pwSuccessMessage = "Mot de passe modifié avec succès."
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
            case .failure(let error):
                pwErrorMessage = Self.message(for: error)
            }
            pwSaving = false
        }
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return "Une erreur est survenue."
        }
    }
}
