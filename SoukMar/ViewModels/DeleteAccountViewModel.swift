import Foundation

/// Mirrors soukmar-android's DeleteAccountViewModel — password re-entry +
/// explicit confirmation checkbox before a soft-delete (anonymize) request.
@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmed = false
    @Published private(set) var submitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var deleted = false

    private let repository = AuthRepository.shared

    var canSubmit: Bool {
        !password.isEmpty && confirmed && !submitting
    }

    func submit(onLoggedOut: @escaping () -> Void) {
        guard canSubmit else { return }
        submitting = true
        errorMessage = nil
        Task {
            switch await repository.deleteAccount(password: password) {
            case .success:
                deleted = true
                repository.logout()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                onLoggedOut()
            case .failure(let error):
                submitting = false
                if case .server(let message, _) = error {
                    errorMessage = message
                } else {
                    errorMessage = "Une erreur est survenue. Veuillez réessayer."
                }
            }
        }
    }
}
