import Foundation

/// Which optional e-mails the account receives (web: /mes-donnees). Sent whole on every change.
struct EmailPreferencesDto: Codable {
    var emailMessages: Bool
    var emailSavedSearches: Bool
    var emailListingReminders: Bool
}

/// An account the user has blocked, shown with the public (shortened) name.
struct BlockedUserDto: Codable, Identifiable {
    let id: String
    var name: String?
    var image: String?
    var blockedAt: String?
}
