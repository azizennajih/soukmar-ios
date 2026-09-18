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

    func register(name: String, email: String, password: String, phone: String?, city: String?, accountType: String) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/register", method: "POST",
                body: RegisterRequest(name: name, email: email, password: password, phone: phone, city: city, accountType: accountType)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func forgotPassword(email: String) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/forgot-password", method: "POST",
                body: ForgotPasswordRequest(email: email)
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

    /// Soft-deletes the account (anonymized, not a hard delete) — mirrors
    /// Android's `deleteAccount()`. Android needs `@HTTP(method="DELETE",
    /// hasBody=true)` since Retrofit's `@DELETE` can't carry a body; a plain
    /// `URLRequest` has no such restriction, so this is just a normal
    /// `send(method: "DELETE", body:)` call.
    func deleteAccount(password: String) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/account", method: "DELETE",
                body: DeleteAccountRequest(password: password)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func updateProfile(name: String, phone: String?, city: String?, accountType: String? = nil) async -> Result<UserDto, APIError> {
        do {
            let response: UserDto = try await api.send(
                path: "auth/profile", method: "PUT",
                body: ProfileUpdateRequest(name: name, phone: phone, city: city, accountType: accountType)
            )
            TokenStore.shared.cachedUser = response
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    /// SMS phone verification — mirrors Android's `sendPhoneCode()`/
    /// `verifyPhoneCode()`. Backend rate-limits both via `phoneActionLimiter`
    /// and expires the code after 10 minutes / 5 wrong attempts.
    func sendPhoneCode() async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(path: "auth/phone/send-code", method: "POST")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func verifyPhoneCode(_ code: String) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/phone/verify", method: "POST",
                body: PhoneVerifyRequest(code: code)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func updateProfileImage(url: String) async -> Result<UserDto, APIError> {
        do {
            let response: UserDto = try await api.send(
                path: "auth/profile", method: "PUT",
                body: ProfileImageUpdateRequest(image: url)
            )
            TokenStore.shared.cachedUser = response
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Result<MessageResponse, APIError> {
        do {
            let response: MessageResponse = try await api.send(
                path: "auth/change-password", method: "PUT",
                body: ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
