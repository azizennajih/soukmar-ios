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
    @Published var accountType = "PRIVATE"
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

    @Published private(set) var phoneCodeSent = false
    @Published var phoneCode = ""
    @Published private(set) var phoneSendingCode = false
    @Published private(set) var phoneVerifying = false
    @Published private(set) var phoneMessage: String?
    @Published private(set) var phoneErrorMessage: String?

    /// Free KYC-lite: "NONE" (never submitted) | "PENDING" | "APPROVED" |
    /// "REJECTED" (resubmission allowed) — mirrors the web's
    /// idVerificationStatus signal.
    @Published private(set) var idVerificationStatus = "NONE"
    @Published private(set) var idVerificationNote: String?
    @Published var idImageData: Data?
    @Published var selfieImageData: Data?
    @Published private(set) var idVerificationSubmitting = false
    @Published private(set) var idVerificationMessage: String?
    @Published private(set) var idVerificationErrorMessage: String?

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
                accountType = user.accountType ?? "PRIVATE"
            } else {
                loadError = true
            }
            loading = false
        }
        loadIdVerificationStatus()
    }

    func loadIdVerificationStatus() {
        Task {
            switch await authRepository.getIdVerificationStatus() {
            case .success(let status):
                idVerificationStatus = status?.status ?? "NONE"
                idVerificationNote = status?.adminNote
            case .failure:
                break // non-essential — just leave the form open, like the web
            }
        }
    }

    func pickIdImage(data: Data) { idImageData = data }
    func pickSelfieImage(data: Data) { selfieImageData = data }

    func submitIdVerification() {
        guard let idData = idImageData, let selfieData = selfieImageData else {
            idVerificationErrorMessage = "Veuillez ajouter les deux photos."
            return
        }
        guard !idVerificationSubmitting else { return }
        idVerificationSubmitting = true
        idVerificationMessage = nil
        idVerificationErrorMessage = nil
        Task {
            async let idUpload = uploadRepository.uploadImages([(data: idData, filename: "id.jpg", mimeType: "image/jpeg")], type: "idVerification")
            async let selfieUpload = uploadRepository.uploadImages([(data: selfieData, filename: "selfie.jpg", mimeType: "image/jpeg")], type: "idVerification")
            let (idResult, selfieResult) = await (idUpload, selfieUpload)

            guard case .success(let idUrls) = idResult, let idImageUrl = idUrls.first,
                  case .success(let selfieUrls) = selfieResult, let selfieImageUrl = selfieUrls.first
            else {
                idVerificationErrorMessage = "L'envoi a échoué. Réessayez."
                idVerificationSubmitting = false
                return
            }

            switch await authRepository.submitIdVerification(idImageUrl: idImageUrl, selfieImageUrl: selfieImageUrl) {
            case .success:
                idVerificationStatus = "PENDING"
                idImageData = nil
                selfieImageData = nil
                idVerificationMessage = "Votre demande a été envoyée. Nous l'examinerons sous peu."
            case .failure(let error):
                idVerificationErrorMessage = Self.message(for: error)
            }
            idVerificationSubmitting = false
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
                city: trimmedCity.isEmpty ? nil : trimmedCity,
                accountType: accountType
            ) {
            case .success(let user):
                profile = user
                successMessage = "Profil mis à jour."
                // A changed phone number invalidates any prior verification
                // server-side — drop any in-progress code entry for the old number.
                phoneCodeSent = false
                phoneCode = ""
                phoneMessage = nil
                phoneErrorMessage = nil
            case .failure(let error):
                errorMessage = Self.message(for: error)
            }
            saving = false
        }
    }

    func sendPhoneCode() {
        guard !phoneSendingCode else { return }
        phoneMessage = nil
        phoneErrorMessage = nil
        phoneSendingCode = true
        Task {
            switch await authRepository.sendPhoneCode() {
            case .success:
                phoneCodeSent = true
                phoneCode = ""
                phoneMessage = "Code envoyé par SMS."
            case .failure(let error):
                phoneErrorMessage = Self.message(for: error)
            }
            phoneSendingCode = false
        }
    }

    func verifyPhoneCode() {
        guard !phoneCode.trimmingCharacters(in: .whitespaces).isEmpty, !phoneVerifying else { return }
        phoneMessage = nil
        phoneErrorMessage = nil
        phoneVerifying = true
        Task {
            switch await authRepository.verifyPhoneCode(phoneCode.trimmingCharacters(in: .whitespaces)) {
            case .success:
                if let current = profile {
                    profile = UserDto(
                        id: current.id, name: current.name, email: current.email, role: current.role,
                        phone: current.phone, city: current.city, image: current.image,
                        createdAt: current.createdAt, accountType: current.accountType,
                        emailVerified: current.emailVerified, phoneVerified: true, idVerified: current.idVerified
                    )
                }
                phoneCodeSent = false
                phoneCode = ""
                phoneMessage = "Numéro de téléphone vérifié avec succès !"
            case .failure(let error):
                phoneErrorMessage = Self.message(for: error)
            }
            phoneVerifying = false
        }
    }

    func pickAvatar(data: Data) {
        guard !uploadingImage else { return }
        uploadingImage = true
        errorMessage = nil
        Task {
            switch await uploadRepository.uploadImages([(data: data, filename: "avatar.jpg", mimeType: "image/jpeg")], type: "avatar") {
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
