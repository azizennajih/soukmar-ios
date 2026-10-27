import Foundation
import Combine

/// Overview / listings / users / visitors / revenue / security of the admin dashboard (web: AdminComponent,
/// Android: AdminDashboardViewModel). Everything except the security log follows `allCountries`: the
/// browsing country, or all countries at once.
@MainActor
final class AdminDashboardViewModel: ObservableObject {
    @Published private(set) var allCountries = false
    @Published private(set) var loading = true

    @Published private(set) var listings: [ListingDto] = []
    @Published private(set) var users: [AdminUserDto] = []
    @Published private(set) var activity: [AdminActivityDto] = []
    @Published private(set) var analytics: AdminAnalyticsDto?
    @Published private(set) var securityEvents: [SecurityEventDto] = []

    @Published var listingFilter = "ALL"
    @Published var userSearch = ""
    @Published var severityFilter = "ALL"
    @Published private(set) var actionFailed = false

    private let repository = AdminDashboardRepository.shared
    private var loadedFor: String?
    private var countryCancellable: AnyCancellable?

    var scopeCountry: String { CountryRepository.shared.country }
    private var queryCountry: String? { allCountries ? nil : CountryRepository.shared.country }

    var revenueCurrency: String { allCountries ? "EUR" : currencyForCountry(CountryRepository.shared.country) }

    /// Reloads when the scope (or the browsing country) changed since the last load.
    func start() {
        if countryCancellable == nil {
            countryCancellable = CountryRepository.shared.$country
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.ensureLoaded() }
        }
        ensureLoaded()
    }

    func setScope(all: Bool) {
        guard allCountries != all else { return }
        allCountries = all
        ensureLoaded()
    }

    private func ensureLoaded() {
        let key = queryCountry ?? "*"
        guard loadedFor != key else { return }
        loadedFor = key
        reload()
    }

    private func reload() {
        loading = true
        let country = queryCountry
        Task {
            if case .success(let data) = await repository.getAllListings(country: country) { listings = data } else { listings = [] }
            if case .success(let data) = await repository.getUsers(country: country) { users = data } else { users = [] }
            if case .success(let data) = await repository.getActivity(country: country) { activity = data } else { activity = [] }
            if case .success(let data) = await repository.getAnalytics(country: country) { analytics = data } else { analytics = nil }
            if case .success(let data) = await repository.getSecurityEvents() { securityEvents = data }
            loading = false
        }
    }

    var filteredListings: [ListingDto] {
        listingFilter == "ALL" ? listings : listings.filter { $0.status == listingFilter }
    }

    var filteredUsers: [AdminUserDto] {
        let q = userSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter { ($0.name ?? "").lowercased().contains(q) || ($0.email ?? "").lowercased().contains(q) }
    }

    var filteredSecurity: [SecurityEventDto] {
        severityFilter == "ALL" ? securityEvents : securityEvents.filter { $0.severity == severityFilter }
    }

    var premiumListings: [ListingDto] { listings.filter { $0.isPremium } }

    func setUserRole(_ user: AdminUserDto, role: String) {
        Task {
            if await repository.setUserRole(id: user.id, role: role) {
                actionFailed = false
                if let index = users.firstIndex(where: { $0.id == user.id }) { users[index].role = role }
            } else { actionFailed = true }
        }
    }

    func setListingStatus(_ listing: ListingDto, status: String) {
        Task {
            if await repository.setListingStatus(id: listing.id, status: status) {
                actionFailed = false
                if let index = listings.firstIndex(where: { $0.id == listing.id }) { listings[index].status = status }
            } else { actionFailed = true }
        }
    }

    func togglePremium(_ listing: ListingDto) {
        let target = !listing.isPremium
        Task {
            if await repository.setListingPremium(id: listing.id, premium: target) {
                actionFailed = false
                if let index = listings.firstIndex(where: { $0.id == listing.id }) { listings[index].isPremium = target }
            } else { actionFailed = true }
        }
    }

    func deleteListing(_ listing: ListingDto) {
        Task {
            if await repository.deleteListing(id: listing.id) {
                actionFailed = false
                listings.removeAll { $0.id == listing.id }
            } else { actionFailed = true }
        }
    }
}
