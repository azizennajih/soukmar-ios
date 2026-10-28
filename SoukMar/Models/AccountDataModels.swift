import Foundation

/// Which optional e-mails the account receives (web: /mes-donnees). Sent whole on every change.
struct EmailPreferencesDto: Codable {
    var emailMessages: Bool
    var emailSavedSearches: Bool
    var emailListingReminders: Bool
    /// Advertising is opt-in: off until the user switches it on.
    var emailMarketing: Bool

    private enum CodingKeys: String, CodingKey {
        case emailMessages, emailSavedSearches, emailListingReminders, emailMarketing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        emailMessages = try c.decode(Bool.self, forKey: .emailMessages)
        emailSavedSearches = try c.decode(Bool.self, forKey: .emailSavedSearches)
        emailListingReminders = try c.decode(Bool.self, forKey: .emailListingReminders)
        emailMarketing = try c.decodeIfPresent(Bool.self, forKey: .emailMarketing) ?? false
    }
}

/// An account the user has blocked, shown with the public (shortened) name.
struct BlockedUserDto: Codable, Identifiable {
    let id: String
    var name: String?
    var image: String?
    var blockedAt: String?
}
