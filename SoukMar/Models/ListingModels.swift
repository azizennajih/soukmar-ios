import Foundation

struct ListingUserDto: Codable {
    let id: String
    let name: String
    var city: String?
}

struct ListingAttributeValueDto: Codable, Identifiable {
    let id: String
    let attributeDefinitionId: String
    var attributeDefinition: AttributeDefinitionDto?
    var valueText: String?
    var valueNumber: Double?
    var valueBoolean: Bool?
}

struct ListingDto: Codable, Identifiable, Equatable {
    static func == (lhs: ListingDto, rhs: ListingDto) -> Bool { lhs.id == rhs.id }

    let id: String
    let title: String
    var description: String = ""
    var price: Double?
    var currency: String = "MAD"
    let category: String
    var subcategoryId: String?
    var condition: String?
    let city: String
    var region: String?
    var images: [String] = []
    var status: String = "ACTIVE"
    var isPremium: Bool = false
    var isFeatured: Bool = false
    var views: Int = 0
    var phone: String?
    var whatsapp: String?
    var showPhone: Bool?
    let userId: String
    var user: ListingUserDto?
    var attributeValues: [ListingAttributeValueDto] = []
    var avgPrice: Double?
    var bumpedAt: String?
    let createdAt: String

    // Swift's synthesized Decodable ignores stored-property defaults for a
    // missing key (unlike kotlinx.serialization on the Android side), and a
    // relation array like attributeValues can legitimately be left out of
    // some endpoint variants — decode leniently so one missing optional
    // field doesn't fail the whole listing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "MAD"
        category = try c.decode(String.self, forKey: .category)
        subcategoryId = try c.decodeIfPresent(String.self, forKey: .subcategoryId)
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        city = try c.decode(String.self, forKey: .city)
        region = try c.decodeIfPresent(String.self, forKey: .region)
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "ACTIVE"
        isPremium = try c.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        isFeatured = try c.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        views = try c.decodeIfPresent(Int.self, forKey: .views) ?? 0
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        whatsapp = try c.decodeIfPresent(String.self, forKey: .whatsapp)
        showPhone = try c.decodeIfPresent(Bool.self, forKey: .showPhone)
        userId = try c.decode(String.self, forKey: .userId)
        user = try c.decodeIfPresent(ListingUserDto.self, forKey: .user)
        attributeValues = try c.decodeIfPresent([ListingAttributeValueDto].self, forKey: .attributeValues) ?? []
        avgPrice = try c.decodeIfPresent(Double.self, forKey: .avgPrice)
        bumpedAt = try c.decodeIfPresent(String.self, forKey: .bumpedAt)
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
}

struct ListingsResponseDto: Codable {
    var listings: [ListingDto] = []
    var total: Int = 0
    var page: Int = 1
    var pages: Int = 1

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listings = try c.decodeIfPresent([ListingDto].self, forKey: .listings) ?? []
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
        pages = try c.decodeIfPresent(Int.self, forKey: .pages) ?? 1
    }
}

// MARK: - Catalog / EAV

struct AttributeDefinitionDto: Codable, Identifiable, Equatable {
    static func == (lhs: AttributeDefinitionDto, rhs: AttributeDefinitionDto) -> Bool { lhs.id == rhs.id }

    let id: String
    let subcategoryId: String
    let code: String
    /// TEXT | NUMBER | SELECT | BOOLEAN
    let type: String
    var required: Bool = false
    var filterable: Bool = false
    var sortOrder: Int = 0
    var options: [String] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        subcategoryId = try c.decode(String.self, forKey: .subcategoryId)
        code = try c.decode(String.self, forKey: .code)
        type = try c.decode(String.self, forKey: .type)
        required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? false
        filterable = try c.decodeIfPresent(Bool.self, forKey: .filterable) ?? false
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
    }
}

struct SubcategoryWithAttributesDto: Codable, Identifiable, Equatable {
    static func == (lhs: SubcategoryWithAttributesDto, rhs: SubcategoryWithAttributesDto) -> Bool { lhs.id == rhs.id }

    let id: String
    let category: String
    let code: String
    var sortOrder: Int = 0
    var attributeDefinitions: [AttributeDefinitionDto] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        category = try c.decode(String.self, forKey: .category)
        code = try c.decode(String.self, forKey: .code)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        attributeDefinitions = try c.decodeIfPresent([AttributeDefinitionDto].self, forKey: .attributeDefinitions) ?? []
    }
}

struct CategoryFullResponse: Codable {
    var subcategories: [SubcategoryWithAttributesDto] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subcategories = try c.decodeIfPresent([SubcategoryWithAttributesDto].self, forKey: .subcategories) ?? []
    }
}
