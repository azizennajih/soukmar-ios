import Foundation

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var loading: Bool = false
    @Published var sent: Bool = false
    @Published var errorMessage: String?

    private let repository = AuthRepository.shared

    func submit() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        loading = true
        errorMessage = nil
        Task {
            let result = await repository.forgotPassword(email: email.trimmingCharacters(in: .whitespaces))
            loading = false
            switch result {
            case .success:
                sent = true
            case .failure(let error):
                if case .server(let message, _) = error { errorMessage = message }
            }
        }
    }
}
