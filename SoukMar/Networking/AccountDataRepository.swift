import Foundation

/// Personal-data self-service endpoints (web: /mes-donnees): e-mail preferences, blocked users and the
/// download of everything stored about the account (GDPR Art. 15 / 20).
final class AccountDataRepository {
    static let shared = AccountDataRepository()
    private let api = APIClient.shared

    func getEmailPreferences() async -> Result<EmailPreferencesDto, APIError> {
        await run { try await self.api.send(path: "auth/email-preferences") }
    }

    func setEmailPreferences(_ prefs: EmailPreferencesDto) async -> Result<EmailPreferencesDto, APIError> {
        await run { try await self.api.send(path: "auth/email-preferences", method: "PUT", body: prefs) }
    }

    func getBlockedUsers() async -> Result<[BlockedUserDto], APIError> {
        await run { try await self.api.send(path: "users/me/blocked") }
    }

    /// The export as the raw JSON the server sent, so what the user saves is exactly what the server holds.
    func exportMyData() async -> Result<Data, APIError> {
        await run { try await self.api.getData(path: "auth/export") }
    }

    private func run<T>(_ call: () async throws -> T) async -> Result<T, APIError> {
        do {
            return .success(try await call())
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(genericErrorText()))
        }
    }
}
