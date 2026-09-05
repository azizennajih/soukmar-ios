import Foundation

/// Mirrors soukmar-android's ListingsViewModel — same filter state and
/// buildParams()/search()/loadMore() contract against GET /api/listings.
/// Saved-search integration is a later iOS phase (Android Phase 10 equivalent),
/// so it's intentionally omitted here.
@MainActor
final class ListingsViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var selectedCategory: String?
    @Published private(set) var selectedSubcategoryId: String?
    @Published private(set) var selectedCondition: String?
    @Published var minPrice: String = ""
    @Published var maxPrice: String = ""

    @Published private(set) var subcategories: [SubcategoryWithAttributesDto] = []
    @Published private(set) var filterableAttributes: [AttributeDefinitionDto] = []

    /// code -> selected option values (SELECT) or "true"/"false" (BOOLEAN)
    @Published private(set) var attrSelections: [String: Set<String>] = [:]
    /// code -> (min, max) raw text for NUMBER attributes
    @Published var attrRanges: [String: (min: String, max: String)] = [:]

    @Published private(set) var listings: [ListingDto] = []
    @Published private(set) var loading = false
    @Published private(set) var loadingMore = false
    @Published private(set) var error: String?
    private var page = 1
    @Published private(set) var hasMore = false

    private let listingRepository = ListingRepository.shared
    private let catalogRepository = CatalogRepository.shared

    init(initialCategory: String? = nil) {
        if let initialCategory {
            selectedCategory = initialCategory
            loadCategoryFilters(initialCategory)
        }
        search()
    }

    func setCategory(_ value: String?) {
        guard selectedCategory != value else { return }
        selectedCategory = value
        selectedSubcategoryId = nil
        selectedCondition = nil
        attrSelections = [:]
        attrRanges = [:]
        subcategories = []
        filterableAttributes = []
        if let value { loadCategoryFilters(value) }
        search()
    }

    func setSubcategory(_ id: String) {
        selectedSubcategoryId = (selectedSubcategoryId == id) ? nil : id
        attrSelections = [:]
        attrRanges = [:]
        if let selectedSubcategoryId {
            filterableAttributes = subcategories.first { $0.id == selectedSubcategoryId }?
                .attributeDefinitions.filter(\.filterable) ?? []
        } else {
            filterableAttributes = Self.unionFilterableAttrs(subcategories)
        }
        search()
    }

    func setCondition(_ value: String) {
        selectedCondition = (selectedCondition == value) ? nil : value
        search()
    }

    func toggleAttrOption(code: String, option: String) {
        var current = attrSelections[code] ?? []
        if current.contains(option) { current.remove(option) } else { current.insert(option) }
        if current.isEmpty { attrSelections.removeValue(forKey: code) } else { attrSelections[code] = current }
        search()
    }

    func setAttrRange(code: String, min: String, max: String) {
        attrRanges[code] = (min, max)
    }

    func applyAttrRange() { search() }

    func clearFilters() {
        selectedSubcategoryId = nil
        selectedCondition = nil
        minPrice = ""
        maxPrice = ""
        attrSelections = [:]
        attrRanges = [:]
        filterableAttributes = Self.unionFilterableAttrs(subcategories)
        search()
    }

    private static func unionFilterableAttrs(_ subs: [SubcategoryWithAttributesDto]) -> [AttributeDefinitionDto] {
        var seen: [String: AttributeDefinitionDto] = [:]
        var order: [String] = []
        for sub in subs {
            for def in sub.attributeDefinitions where def.filterable {
                if seen[def.code] == nil {
                    seen[def.code] = def
                    order.append(def.code)
                }
            }
        }
        return order.compactMap { seen[$0] }
    }

    private func loadCategoryFilters(_ category: String) {
        Task {
            switch await catalogRepository.getCategoryFull(category: category) {
            case .success(let data):
                subcategories = data.subcategories
                filterableAttributes = Self.unionFilterableAttrs(data.subcategories)
            case .failure:
                break // filter sidebar is optional; browsing still works without it
            }
        }
    }

    private func buildParams(targetPage: Int) -> [String: String] {
        var params: [String: String] = ["page": "\(targetPage)", "limit": "20"]
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty { params["q"] = trimmedQuery }
        if let selectedCategory { params["category"] = selectedCategory }
        if let selectedSubcategoryId { params["subcategoryId"] = selectedSubcategoryId }
        if let selectedCondition { params["condition"] = selectedCondition }
        if !minPrice.isEmpty { params["minPrice"] = minPrice }
        if !maxPrice.isEmpty { params["maxPrice"] = maxPrice }
        for (code, values) in attrSelections where !values.isEmpty {
            params["attr_\(code)"] = values.joined(separator: ",")
        }
        for (code, range) in attrRanges {
            if !range.min.isEmpty { params["attr_\(code)_min"] = range.min }
            if !range.max.isEmpty { params["attr_\(code)_max"] = range.max }
        }
        return params
    }

    func search() {
        page = 1
        loading = true
        error = nil
        Task {
            switch await listingRepository.getListings(params: buildParams(targetPage: 1)) {
            case .success(let data):
                listings = data.listings
                hasMore = data.page < data.pages
            case .failure(let err):
                error = Self.message(for: err)
            }
            loading = false
        }
    }

    func loadMore() {
        guard !loadingMore, hasMore else { return }
        loadingMore = true
        let nextPage = page + 1
        Task {
            switch await listingRepository.getListings(params: buildParams(targetPage: nextPage)) {
            case .success(let data):
                listings += data.listings
                page = nextPage
                hasMore = data.page < data.pages
            case .failure:
                break // keep current page on a load-more failure
            }
            loadingMore = false
        }
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return "Une erreur est survenue."
        }
    }
}
