import Foundation

/// Personal-data self-service (web: /mes-donnees, Android: MesDonneesViewModel): e-mail preferences,
/// blocked users, data download.
@MainActor
final class MesDonneesViewModel: ObservableObject {
    @Published private(set) var prefs: EmailPreferencesDto?
    @Published private(set) var blocked: [BlockedUserDto]?
    @Published private(set) var exporting = false
    @Published private(set) var errorMessage: String?
    /// The prepared export file; setting it opens the share sheet where the user chooses where to save it.
    @Published var exportFile: URL?

    private let repository = AccountDataRepository.shared

    func load() {
        Task {
            if case .success(let data) = await repository.getEmailPreferences() { prefs = data }
            if case .success(let data) = await repository.getBlockedUsers() { blocked = data } else { blocked = [] }
        }
    }

    /// Saves right away; the switch goes back if the server refuses.
    func setPref(_ keyPath: WritableKeyPath<EmailPreferencesDto, Bool>, _ value: Bool) {
        guard let current = prefs else { return }
        var next = current
        next[keyPath: keyPath] = value
        prefs = next
        Task {
            switch await repository.setEmailPreferences(next) {
            case .success(let saved):
                prefs = saved
                errorMessage = nil
            case .failure(let error):
                prefs = current
                errorMessage = Self.message(for: error)
            }
        }
    }

    func unblock(_ user: BlockedUserDto) {
        Task {
            switch await UserRepository.shared.unblockUser(id: user.id) {
            case .success:
                blocked = blocked?.filter { $0.id != user.id }
                errorMessage = nil
            case .failure(let error):
                errorMessage = Self.message(for: error)
            }
        }
    }

    func prepareExport() {
        guard !exporting else { return }
        exporting = true
        Task {
            switch await repository.exportMyData() {
            case .success(let data):
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("souqmar24-my-data.json")
                do {
                    try data.write(to: url, options: .atomic)
                    exportFile = url
                    errorMessage = nil
                } catch {
                    errorMessage = appText("mes_donnees.export_error", genericErrorText())
                }
            case .failure:
                errorMessage = appText("mes_donnees.export_error", genericErrorText())
            }
            exporting = false
        }
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return genericErrorText()
        }
    }
}
