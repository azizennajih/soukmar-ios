import Foundation

struct CreateConversationRequest: Encodable {
    let listingId: String
}

struct ChatUserDto: Codable {
    let id: String
    let name: String
}

struct ChatListingDto: Codable {
    let id: String
    let title: String
    var price: Double?
    var currency: String = "MAD"
    var images: [String] = []
    let userId: String
    var status: String = "ACTIVE"
    let user: ChatUserDto

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "MAD"
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        userId = try c.decode(String.self, forKey: .userId)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "ACTIVE"
        user = try c.decode(ChatUserDto.self, forKey: .user)
    }
}

/// Mirrors soukmar-backend's Message model. `type` is TEXT | OFFER | SYSTEM,
/// `offerStatus` (OFFER only) is PENDING | ACCEPTED | REJECTED | COUNTERED.
struct MessageDto: Codable, Identifiable, Equatable {
    static func == (lhs: MessageDto, rhs: MessageDto) -> Bool { lhs.id == rhs.id }

    let id: String
    let content: String
    let type: String
    var offerAmount: Double?
    var offerStatus: String?
    var isRead: Bool = false
    let senderId: String
    let receiverId: String
    var listingId: String?
    var conversationId: String?
    let createdAt: String
    var sender: ChatUserDto?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        type = try c.decode(String.self, forKey: .type)
        offerAmount = try c.decodeIfPresent(Double.self, forKey: .offerAmount)
        offerStatus = try c.decodeIfPresent(String.self, forKey: .offerStatus)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        senderId = try c.decode(String.self, forKey: .senderId)
        receiverId = try c.decode(String.self, forKey: .receiverId)
        listingId = try c.decodeIfPresent(String.self, forKey: .listingId)
        conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        sender = try c.decodeIfPresent(ChatUserDto.self, forKey: .sender)
    }
}

/// `messages` is populated (last message only) by GET /chat/conversations
/// for the list preview; empty when fetched some other way.
struct ConversationDto: Codable, Identifiable, Equatable {
    static func == (lhs: ConversationDto, rhs: ConversationDto) -> Bool { lhs.id == rhs.id }

    let id: String
    let listingId: String
    let buyerId: String
    var updatedAt: String = ""
    let listing: ChatListingDto
    let buyer: ChatUserDto
    var messages: [MessageDto] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        listingId = try c.decode(String.self, forKey: .listingId)
        buyerId = try c.decode(String.self, forKey: .buyerId)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        listing = try c.decode(ChatListingDto.self, forKey: .listing)
        buyer = try c.decode(ChatUserDto.self, forKey: .buyer)
        messages = try c.decodeIfPresent([MessageDto].self, forKey: .messages) ?? []
    }

    /// True when `myId` is the listing's seller — the conversation's "other
    /// side" is then the buyer, and vice versa. Mirrors Android's
    /// ConversationDto.partnerId()/partnerName().
    func partnerId(myId: String?) -> String {
        listing.userId == myId ? buyerId : listing.userId
    }

    func partnerName(myId: String?) -> String {
        listing.userId == myId ? buyer.name : listing.user.name
    }
}
