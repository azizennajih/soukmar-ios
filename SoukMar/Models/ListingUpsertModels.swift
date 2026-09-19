import Foundation

/// A dynamic attribute value sent to POST/PUT /api/listings — the backend's
/// `validateAttributes()` (soukmar-backend/src/lib/attributes.ts) coerces a
/// JSON string into a number/boolean itself via zod, so even NUMBER-typed
/// attributes travel as plain text here, mirroring Android's
/// `setAttrText()` (only BOOLEAN attributes use an actual JSON boolean).
enum AttrValue: Encodable {
    case text(String)
    case bool(Bool)
    /// MULTI_SELECT travels as a JSON array of option codes — the backend's
    /// `buildAttributeValueRows()` (soukmar-backend/src/lib/attributes.ts)
    /// turns it into one ListingAttributeValue row per entry, mirroring
    /// Android's `JsonArray(options.map { JsonPrimitive(it) })`.
    case stringArray([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .stringArray(let value): try container.encode(value)
        }
    }
}

/// No `currency` field on purpose: the backend derives it server-side from
/// `country` (currencyForCountry) since the international-country tranche —
/// mirrors web's deposer-annonce.component.ts publish() payload / Android's
/// ListingUpsertRequest, which dropped their own currency field the same way.
struct ListingUpsertRequest: Encodable {
    var title: String
    var description: String
    var price: Double?
    var category: String
    var subcategoryId: String?
    var condition: String?
    var city: String
    var country: String
    var images: [String] = []
    var phone: String?
    var whatsapp: String?
    var showPhone: Bool = true
    var attributes: [String: AttrValue] = [:]
}

struct UploadResponseDto: Codable {
    var urls: [String] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        urls = try c.decodeIfPresent([String].self, forKey: .urls) ?? []
    }
}
