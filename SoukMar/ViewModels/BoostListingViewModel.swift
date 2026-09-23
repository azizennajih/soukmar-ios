import Foundation

/// Mirrors soukmar-android's BoostListingViewModel — loads the listing +
/// its current boost status, holds the seller's tier selection, and submits
/// a boost request (queued PENDING until an admin approves it, see
/// BoostModels.swift).
@MainActor
final class BoostListingViewModel: ObservableObject {
    @Published private(set) var listing: ListingDto?
    @Published private(set) var boostStatus: BoostStatusDto?
    @Published private(set) var loading = true
    @Published private(set) var loadError = false

    @Published var selectedTiers: Set<BoostTierId> = []

    @Published private(set) var submitting = false
    @Published private(set) var submitted = false
    @Published var errorMessage: String?

    private let listingRepository = ListingRepository.shared
    private var listingId = ""

    func load(id: String) {
        listingId = id
        Task {
            loading = true
            loadError = false
            async let listingResult = listingRepository.getListing(id: id)
            async let statusResult = listingRepository.getBoostStatus(id: id)
            switch await listingResult {
            case .success(let data): listing = data
            case .failure: loadError = true
            }
            if case .success(let data) = await statusResult { boostStatus = data }
            loading = false
        }
    }

    func toggle(_ tier: BoostTierId) {
        if selectedTiers.contains(tier) { selectedTiers.remove(tier) } else { selectedTiers.insert(tier) }
    }

    /// True while `until` (an ISO date string from `boostStatus`) is still in the future.
    func isActiveUntil(_ until: String?) -> Bool { isBoostActive(until) }

    func activeUntil(for tier: BoostTierId) -> String? {
        let raw: String?
        switch tier {
        case .spotlight: raw = boostStatus?.boostSpotlightUntil
        case .top: raw = boostStatus?.boostTopUntil
        case .global: raw = boostStatus?.boostGlobalUntil
        case .bump: raw = nil
        }
        return isActiveUntil(raw) ? raw : nil
    }

    func submit(onSelectAtLeastOne: () -> Void) {
        guard !selectedTiers.isEmpty else { onSelectAtLeastOne(); return }
        guard !submitting else { return }
        submitting = true
        errorMessage = nil
        Task {
            switch await listingRepository.requestBoost(id: listingId, tiers: selectedTiers.map(\.rawValue)) {
            case .success(let data):
                if boostStatus == nil {
                    boostStatus = BoostStatusDto(pendingRequest: data)
                } else {
                    boostStatus?.pendingRequest = data
                }
                submitted = true
            case .failure(let error):
                errorMessage = Self.message(for: error)
            }
            submitting = false
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
