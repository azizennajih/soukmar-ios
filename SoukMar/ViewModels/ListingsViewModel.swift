import Foundation

/// Mirrors soukmar-android's ListingsViewModel — same filter state,
/// buildParams()/search()/loadMore() contract against GET /api/listings,
/// and saved-search save/restore (Android Phase 10 equivalent). No city
/// filter exists here (never did on Android either) so a saved search's
/// `city` field is never set on create.
@MainActor
final class ListingsViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var selectedCategory: String?
    @Published private(set) var selectedSubcategoryId: String?
    @Published private(set) var selectedCondition: String?
    @Published private(set) var selectedAccountType: String?
    @Published var minPrice: String = ""
    @Published var maxPrice: String = ""

    @Published private(set) var sortBy: String = ""
    @Published private(set) var lat: Double?
    @Published private(set) var lng: Double?
    @Published var radius: String = "10"
    @Published private(set) var locationLoading = false
    @Published private(set) var locationError: String?

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

    @Published var showSaveSearchForm = false
    @Published var newSearchName = ""
    @Published private(set) var savingSearch = false
    @Published private(set) var searchSaved = false
    @Published private(set) var saveSearchError: String?
    @Published private(set) var editSearchId: String?

    private let listingRepository = ListingRepository.shared
    private let catalogRepository = CatalogRepository.shared
    private let savedSearchRepository = SavedSearchRepository.shared

    init(initialCategory: String? = nil, savedSearchId: String? = nil, editSearchId: String? = nil) {
        if let initialCategory {
            selectedCategory = initialCategory
            loadCategoryFilters(initialCategory)
        }
        search()
        if let editSearchId {
            applySavedSearchForEdit(editSearchId)
        } else if let savedSearchId {
            applySavedSearchById(savedSearchId)
        }
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

    func setAccountType(_ value: String) {
        selectedAccountType = (selectedAccountType == value) ? nil : value
        search()
    }

    /// Mirrors Android's `showCondition` — hides "Neuf/Occasion" for
    /// subcategories that opt out even within an otherwise physical-goods
    /// category (e.g. Sport & Loisirs' "Offres d'entraînement" coaching).
    var showCondition: Bool {
        guard let selectedCategory, CONDITION_CATEGORIES.contains(selectedCategory) else { return false }
        guard let subCode = subcategories.first(where: { $0.id == selectedSubcategoryId })?.code else { return true }
        return !NO_CONDITION_SUBCATEGORIES.contains(subCode)
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

    func setSort(_ value: String) {
        sortBy = value
        search()
    }

    func setRadius(_ value: String) {
        radius = value
        search()
    }

    /// Mirrors web's `useGps()`: on success, replaces the (non-existent,
    /// here) city filter with the device's own coordinates and defaults the
    /// radius to 10 km, same as `onGpsSelected()` does when none was set yet.
    func useCurrentLocation() {
        guard !locationLoading else { return }
        locationLoading = true
        locationError = nil
        Task {
            do {
                let coordinate = try await LocationService.shared.requestCurrentLocation()
                lat = coordinate.latitude
                lng = coordinate.longitude
                if radius.isEmpty { radius = "10" }
                search()
            } catch {
                locationError = "annonces.gps_error"
            }
            locationLoading = false
        }
    }

    func clearLocation() {
        lat = nil
        lng = nil
        locationError = nil
        search()
    }

    func clearFilters() {
        selectedSubcategoryId = nil
        selectedCondition = nil
        selectedAccountType = nil
        minPrice = ""
        maxPrice = ""
        attrSelections = [:]
        attrRanges = [:]
        sortBy = ""
        lat = nil
        lng = nil
        radius = "10"
        locationError = nil
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
        if let selectedAccountType { params["accountType"] = selectedAccountType }
        if !minPrice.isEmpty { params["minPrice"] = minPrice }
        if !maxPrice.isEmpty { params["maxPrice"] = maxPrice }
        for (code, values) in attrSelections where !values.isEmpty {
            params["attr_\(code)"] = values.joined(separator: ",")
        }
        for (code, range) in attrRanges {
            if !range.min.isEmpty { params["attr_\(code)_min"] = range.min }
            if !range.max.isEmpty { params["attr_\(code)_max"] = range.max }
        }
        if !sortBy.isEmpty { params["tri"] = sortBy }
        if let lat, let lng {
            params["lat"] = "\(lat)"
            params["lng"] = "\(lng)"
            if !radius.isEmpty { params["radius"] = radius }
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

    func saveSearch() {
        let trimmedName = newSearchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !savingSearch else { return }
        savingSearch = true
        saveSearchError = nil
        Task {
            let attrs: [String: [String]]? = {
                let filtered = attrSelections.filter { !$0.value.isEmpty }.mapValues { Array($0) }
                return filtered.isEmpty ? nil : filtered
            }()
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = SavedSearchCreateRequest(
                name: trimmedName,
                category: selectedCategory,
                subcategoryId: selectedSubcategoryId,
                q: trimmedQuery.isEmpty ? nil : trimmedQuery,
                city: nil,
                minPrice: Double(minPrice),
                maxPrice: Double(maxPrice),
                condition: selectedCondition,
                attrs: attrs
            )
            let result: Result<SavedSearchDto, APIError>
            if let editing = editSearchId {
                result = await savedSearchRepository.update(id: editing, body)
            } else {
                result = await savedSearchRepository.create(body)
            }
            switch result {
            case .success:
                showSaveSearchForm = false
                newSearchName = ""
                editSearchId = nil
                searchSaved = true
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                searchSaved = false
            case .failure(let error):
                saveSearchError = Self.message(for: error)
            }
            savingSearch = false
        }
    }

    func cancelSaveSearch() {
        showSaveSearchForm = false
        saveSearchError = nil
        newSearchName = ""
        editSearchId = nil
    }

    /// Re-fetches the user's saved searches to find `id` and re-applies its
    /// stored filters — there's no GET-by-id endpoint, only the list one.
    func applySavedSearchById(_ id: String) {
        Task {
            switch await savedSearchRepository.getAll() {
            case .success(let all):
                if let saved = all.first(where: { $0.id == id }) {
                    await applySavedSearch(saved)
                }
            case .failure:
                break // fall back to whatever filters are already set
            }
        }
    }

    /// Same as `applySavedSearchById` but also opens the save-search form
    /// pre-filled with the existing name and marks it for update-in-place —
    /// entered from SavedSearchesView's "Modifier" action. Mirrors Android's
    /// `applySavedSearchForEdit()`.
    func applySavedSearchForEdit(_ id: String) {
        Task {
            switch await savedSearchRepository.getAll() {
            case .success(let all):
                if let saved = all.first(where: { $0.id == id }) {
                    await applySavedSearch(saved)
                    editSearchId = saved.id
                    newSearchName = saved.name
                    showSaveSearchForm = true
                }
            case .failure:
                break // fall back to whatever filters are already set
            }
        }
    }

    private func applySavedSearch(_ saved: SavedSearchDto) async {
        query = saved.q ?? ""
        minPrice = saved.minPrice.map(Self.formatPlain) ?? ""
        maxPrice = saved.maxPrice.map(Self.formatPlain) ?? ""
        selectedCondition = saved.condition
        selectedSubcategoryId = saved.subcategoryId
        attrSelections = Dictionary(uniqueKeysWithValues: (saved.attrs ?? [:]).map { ($0.key, Set($0.value)) })
        attrRanges = [:]
        selectedCategory = saved.category

        if let category = saved.category {
            switch await catalogRepository.getCategoryFull(category: category) {
            case .success(let data):
                subcategories = data.subcategories
                if let subcategoryId = saved.subcategoryId {
                    filterableAttributes = subcategories.first { $0.id == subcategoryId }?
                        .attributeDefinitions.filter(\.filterable) ?? Self.unionFilterableAttrs(subcategories)
                } else {
                    filterableAttributes = Self.unionFilterableAttrs(subcategories)
                }
            case .failure:
                subcategories = []
                filterableAttributes = []
            }
        } else {
            subcategories = []
            filterableAttributes = []
        }
        search()
    }

    private static func formatPlain(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return "Une erreur est survenue."
        }
    }
}
