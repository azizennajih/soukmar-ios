import Foundation

/// Mirrors soukmar-android's SavedSearchesViewModel.
@MainActor
final class SavedSearchesViewModel: ObservableObject {
    @Published private(set) var searches: [SavedSearchDto] = []
    @Published private(set) var loading = true

    private let savedSearchRepository = SavedSearchRepository.shared

    func load() {
        Task {
            loading = true
            switch await savedSearchRepository.getAll() {
            case .success(let data):
                searches = data
            case .failure:
                break // keep whatever list was already shown
            }
            loading = false
        }
    }

    func remove(_ id: String) {
        let previous = searches
        searches.removeAll { $0.id == id }
        Task {
            if !(await savedSearchRepository.delete(id: id)) {
                searches = previous
            }
        }
    }
}
