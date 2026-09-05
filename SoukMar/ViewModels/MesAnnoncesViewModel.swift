import Foundation

/// Mirrors soukmar-android's MesAnnoncesViewModel — bump cooldown, optimistic
/// reserve/unreserve toggle, lazy-loaded per-listing view stats, delete
/// confirmation.
@MainActor
final class MesAnnoncesViewModel: ObservableObject {
    @Published private(set) var listings: [ListingDto] = []
    @Published private(set) var loading = true

    @Published private(set) var bumpingId: String?
    @Published private(set) var statsOpenId: String?
    @Published private(set) var statsData: [String: [ViewStatDayDto]] = [:]
    @Published var deleteConfirmId: String?

    @Published private(set) var toastMessage: String?

    private let listingRepository = ListingRepository.shared

    func load() {
        Task {
            loading = true
            switch await listingRepository.getMyListings() {
            case .success(let data):
                listings = data
            case .failure(let error):
                toastMessage = Self.message(for: error)
            }
            loading = false
        }
    }

    func canBump(_ listing: ListingDto) -> Bool {
        guard let bumpedAt = listing.bumpedAt else { return true }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso8601.date(from: bumpedAt)
        if date == nil {
            iso8601.formatOptions = [.withInternetDateTime]
            date = iso8601.date(from: bumpedAt)
        }
        guard let date else { return true }
        return Date().timeIntervalSince(date) >= 24 * 3600
    }

    func bump(_ listing: ListingDto) {
        guard bumpingId == nil, canBump(listing) else { return }
        bumpingId = listing.id
        Task {
            switch await listingRepository.bump(id: listing.id) {
            case .success(let updated):
                listings = listings.map { $0.id == listing.id ? Self.applying(bumpedAt: updated.bumpedAt, to: $0) : $0 }
            case .failure(let error):
                toastMessage = Self.message(for: error)
            }
            bumpingId = nil
        }
    }

    func toggleReserve(_ listing: ListingDto) {
        let nextStatus = listing.status == "RESERVED" ? "ACTIVE" : "RESERVED"
        let previous = listings
        listings = listings.map { $0.id == listing.id ? Self.applying(status: nextStatus, to: $0) : $0 }
        Task {
            switch await listingRepository.updateStatus(id: listing.id, status: nextStatus) {
            case .success:
                break // optimistic value already applied
            case .failure:
                listings = previous
            }
        }
    }

    func toggleStats(_ listing: ListingDto) {
        let id = listing.id
        statsOpenId = statsOpenId == id ? nil : id
        guard statsOpenId == id, statsData[id] == nil else { return }
        Task {
            switch await listingRepository.getViewStats(id: id) {
            case .success(let data):
                statsData[id] = data.days
            case .failure:
                break // stats panel just stays empty on failure
            }
        }
    }

    func requestDelete(_ id: String) { deleteConfirmId = id }
    func dismissDelete() { deleteConfirmId = nil }
    func confirmDelete() {
        guard let id = deleteConfirmId else { return }
        deleteConfirmId = nil
        Task {
            if await listingRepository.deleteListing(id: id) {
                listings.removeAll { $0.id == id }
            }
        }
    }

    func clearToast() { toastMessage = nil }

    private static func applying(bumpedAt: String?, to listing: ListingDto) -> ListingDto {
        var copy = listing
        copy.bumpedAt = bumpedAt
        return copy
    }

    private static func applying(status: String, to listing: ListingDto) -> ListingDto {
        var copy = listing
        copy.status = status
        return copy
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return "Une erreur est survenue."
        }
    }
}
