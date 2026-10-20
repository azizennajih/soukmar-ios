import Foundation

// Mirrors the staff API of the listing review workflow (`/api/admin/moderation`, backend routes/moderation.ts) and
// soukmar-android's ModerationDto.kt. Only ADMIN and MODERATOR accounts get answers; the server checks everything again.
//
// Swift's synthesized Decodable already treats a missing key of an *optional* property as nil, so every field the server
// may leave out is optional here and read through a small computed accessor with a default.

/// A JSON scalar (string, number or bool) — the `params` of a warning mix numbers and strings.
enum JSONScalar: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .number(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }

    var text: String {
        switch self {
        case .string(let s): return s
        case .number(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        }
    }
}

struct ModerationSummaryDto: Codable {
    var pending: Int?
    var changesRequested: Int?
    var suspended: Int?
    var decidedToday: Int?
    var highRiskPending: Int?
    var oldestPendingSince: String?
}

struct ModerationSignalDto: Codable {
    let code: String
    var severity: String?
    var message: String?
    var params: [String: JSONScalar]?

    var level: String { severity ?? "low" }
    var paramStrings: [String: String] { (params ?? [:]).mapValues { $0.text } }
}

struct ModerationSellerShortDto: Codable {
    var id: String?
    var name: String?
}

struct ModerationQueueItemDto: Codable, Identifiable {
    let id: String
    let title: String
    let category: String
    var country: String?
    var city: String?
    var price: Double?
    var priceType: String?
    var currency: String?
    let status: String
    var images: [String]?
    var imageCount: Int?
    let createdAt: String
    var submittedAt: String?
    var moderationReason: String?
    var moderationSignals: [ModerationSignalDto]?
    var user: ModerationSellerShortDto?

    var signals: [ModerationSignalDto] { moderationSignals ?? [] }
}

struct ModerationQueueDto: Codable {
    var total: Int?
    var page: Int?
    var pages: Int?
    var listings: [ModerationQueueItemDto]?
}

struct ModerationListingDto: Codable {
    let id: String
    let title: String
    var description: String?
    var price: Double?
    var priceType: String?
    var currency: String?
    let category: String
    var city: String?
    var country: String?
    var images: [String]?
    let status: String
    var phone: String?
    var whatsapp: String?
    var moderationReason: String?
    var moderationSignals: [ModerationSignalDto]?

    var signals: [ModerationSignalDto] { moderationSignals ?? [] }
}

struct ModerationSellerDto: Codable {
    var name: String?
    var email: String?
    var phone: String?
    var emailVerified: Bool?
    var phoneVerified: Bool?
    var idVerified: Bool?
    var createdAt: String?
    var listingsTotal: Int?
    var listingsPublic: Int?
    var listingsRejected: Int?
    var reportsAgainst: Int?
}

struct ModerationDuplicateListingDto: Codable {
    let id: String
    var title: String?
    var status: String?
}

struct ModerationDuplicateDto: Codable {
    let code: String
    var severity: String?
    var message: String?
    var params: [String: JSONScalar]?
    var listing: ModerationDuplicateListingDto?

    var level: String { severity ?? "low" }
    var paramStrings: [String: String] { (params ?? [:]).mapValues { $0.text } }
}

struct ModerationEventDto: Codable, Identifiable {
    let id: String
    var fromStatus: String?
    let toStatus: String
    var actorName: String?
    var actorRole: String?
    var reason: String?
    var emailKind: String?
    var emailStatus: String?
    var emailSentAt: String?
    var emailError: String?
    let createdAt: String
}

struct ModerationDetailDto: Codable {
    let listing: ModerationListingDto
    var seller: ModerationSellerDto?
    var duplicates: [ModerationDuplicateDto]?
    var events: [ModerationEventDto]?
    /// snake_case names: approve, reject, request_changes, suspend, requeue
    var allowedActions: [String]?
}

struct ModerationDecisionRequest: Encodable {
    var reason: String?
    var allowResubmit: Bool?
    /// The status the admin saw; the server refuses the decision (409) if another reviewer was faster.
    var expectedStatus: String?
}

struct ModerationDecisionEventDto: Codable {
    var emailStatus: String?
}

struct ModerationDecisionResponseDto: Codable {
    var ok: Bool?
    var status: String?
    var event: ModerationDecisionEventDto?
}

struct ModerationResendResponseDto: Codable {
    var ok: Bool?
    var emailStatus: String?
}
