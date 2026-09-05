import Foundation

/// Mirrors soukmar-backend's Notification model / /api/notifications routes.
/// No dedicated title/body field — display text is built client-side from
/// `type` + `actorName` + `listingTitle`, same as Android (no i18n layer on
/// iOS yet either, so hardcoded French strings — see NotificationsView).
struct NotificationDto: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let type: String
    var actorName: String?
    var listingId: String?
    var listingTitle: String?
    var conversationId: String?
    var isRead: Bool = false
    let createdAt: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        type = try c.decode(String.self, forKey: .type)
        actorName = try c.decodeIfPresent(String.self, forKey: .actorName)
        listingId = try c.decodeIfPresent(String.self, forKey: .listingId)
        listingTitle = try c.decodeIfPresent(String.self, forKey: .listingTitle)
        conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
}

struct UnreadCountResponse: Codable {
    var count: Int = 0

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}
