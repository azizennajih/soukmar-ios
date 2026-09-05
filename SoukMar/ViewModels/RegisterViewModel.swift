import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var city: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var loading: Bool = false
    @Published var errorMessage: String?
    @Published var registeredEmail: String?
    @Published var emailSent: Bool = false
    @Published var resendLoading: Bool = false
    @Published var resendOk: Bool = false

    private let repository = AuthRepository.shared

    func submit() {
        guard password == confirmPassword else {
            errorMessage = "Les mots de passe ne correspondent pas."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Le mot de passe doit contenir au moins 6 caractères."
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Champs requis manquants."
            return
        }

        loading = true
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        Task {
            let result = await repository.register(
                name: name.trimmingCharacters(in: .whitespaces),
                email: trimmedEmail,
                password: password,
                phone: phone.isEmpty ? nil : phone,
                city: city.isEmpty ? nil : city
            )
            loading = false
            switch result {
            case .success:
                registeredEmail = trimmedEmail
                emailSent = true
            case .failure(let error):
                if case .server(let message, _) = error {
                    errorMessage = message
                } else {
                    errorMessage = "Erreur réseau."
                }
            }
        }
    }

    func resend() {
        guard let target = registeredEmail, !resendLoading else { return }
        resendLoading = true
        resendOk = false
        Task {
            let result = await repository.resendVerification(email: target)
            resendLoading = false
            if case .success = result { resendOk = true }
        }
    }
}
