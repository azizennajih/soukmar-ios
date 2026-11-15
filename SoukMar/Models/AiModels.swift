import Foundation

/// GET ai/status. `configured == false` (no AI machine set up on the server): the assistant is not shown at all.
struct AiStatusDto: Codable {
    var configured: Bool?
    var available: Bool?
    var maxImages: Int?
}

struct AiCategorySuggestionDto: Codable {
    let category: String
    var subcategoryCode: String?
    var subcategoryId: String?

    enum CodingKeys: String, CodingKey {
        case category
        case subcategoryCode = "subcategory_code"
        case subcategoryId = "subcategory_id"
    }
}

/// A suggested attribute value: an option code or free text, or a yes/no.
enum AiAttrValue: Codable {
    case text(String)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let s = try? container.decode(String.self) {
            self = .text(s)
        } else {
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .bool(let b): try container.encode(b)
        }
    }
}

/// Answer of POST ai/listing-draft, already validated against the catalog by the backend.
struct AiListingDraftDto: Codable {
    var productName: String?
    var suggestedTitle: String?
    var suggestedDescription: String?
    let suggestedCategory: AiCategorySuggestionDto
    var alternativeCategories: [AiCategorySuggestionDto]?
    /// values keyed by attribute code of the suggested subcategory
    var attributes: [String: AiAttrValue]?
    var missingAttributes: [String]?
    var confidence: Double?
    var missingInformation: [String]?
    var keywords: [String]?
    var brand: String?
    var cached: Bool?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case suggestedTitle = "suggested_title"
        case suggestedDescription = "suggested_description"
        case suggestedCategory = "suggested_category"
        case alternativeCategories = "alternative_categories"
        case attributes
        case missingAttributes = "missing_attributes"
        case confidence
        case missingInformation = "missing_information"
        case keywords
        case brand
        case cached
    }
}

/// Error body of the AI routes: `code` is AI_UNAVAILABLE | AI_BUSY | AI_FAILED.
struct AiErrorDto: Codable {
    var error: String?
    var code: String?
}

/// Outcome of the AI listing assistant: `message` is the server's text in the app language, if any.
enum AiDraftOutcome {
    case success(AiListingDraftDto)
    case failed(message: String?, unavailable: Bool)
}
