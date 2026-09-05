import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var loading: Bool = false
    @Published var errorMessage: String?
    @Published var unverifiedEmail: String?
    @Published var resendLoading: Bool = false
    @Published var resendOk: Bool = false

    private let repository = AuthRepository.shared

    func submit(onSuccess: @escaping () -> Void) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Veuillez remplir tous les champs."
            return
        }
        loading = true
        errorMessage = nil
        unverifiedEmail = nil
        Task {
            let result = await repository.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
            loading = false
            switch result {
            case .success:
                onSuccess()
            case .failure(let error):
                if case .server(let message, let unverified) = error {
                    errorMessage = message
                    if unverified { unverifiedEmail = email.trimmingCharacters(in: .whitespaces) }
                } else {
                    errorMessage = "Erreur réseau."
                }
            }
        }
    }

    func resendVerification() {
        guard let target = unverifiedEmail, !resendLoading else { return }
        resendLoading = true
        resendOk = false
        Task {
            let result = await repository.resendVerification(email: target)
            resendLoading = false
            switch result {
            case .success:
                resendOk = true
            case .failure(let error):
                if case .server(let message, _) = error { errorMessage = message }
            }
        }
    }
}
