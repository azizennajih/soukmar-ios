import Foundation

/// Mirrors soukmar-android's AuthRepository — thin wrapper translating
/// APIClient calls/errors into a simple Result-ish shape for ViewModels.
final class AuthRepository {
    static let shared = AuthRepository()
    private let api = APIClient.shared

    func login(email: String, password: String) async -> Result<UserDto, APIError> {
        do {
            let response: LoginResponse = try await api.send(
                path: "auth/login", method: "POST",
                body: LoginRequest(email: email, password: password)
            )
            TokenStore.shared.saveSession(token: response.token, user: response.user)
            return .success(response.user)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func register(name: String, email: String, password: String, phone: String?, city: String?) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/register", method: "POST",
                body: RegisterRequest(name: name, email: email, password: password, phone: phone, city: city)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func resendVerification(email: String) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/resend-verification", method: "POST",
                body: ForgotPasswordRequest(email: email)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func me() async -> UserDto? {
        do {
            let user: UserDto = try await api.send(path: "auth/me")
            TokenStore.shared.cachedUser = user
            return user
        } catch {
            return nil
        }
    }

    func logout() {
        TokenStore.shared.clear()
    }
}
