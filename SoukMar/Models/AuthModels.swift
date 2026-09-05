import Foundation

/// Mirrors soukmar-backend's User shape (password/verification fields
/// stripped server-side before the response) — same contract already used
/// by soukmar-android's UserDto.
struct UserDto: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    var role: String = "USER"
    var phone: String?
    var city: String?
    var image: String?
    var createdAt: String?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let user: UserDto
    let token: String
}

struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
    var phone: String?
    var city: String?
}

struct MessageResponse: Codable {
    var message: String?
    var emailSent: Bool = false
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

/// Mirrors soukmar-backend's generic `{ error, unverified? }` error body.
struct ApiErrorDto: Codable {
    var error: String?
    var unverified: Bool = false
}
