import Foundation

/// Mirrors soukmar-android's CatalogRepository — GET catalog/categories/{category}/full.
final class CatalogRepository {
    static let shared = CatalogRepository()
    private let api = APIClient.shared

    func getCategoryFull(category: String) async -> Result<CategoryFullResponse, APIError> {
        do {
            let response: CategoryFullResponse = try await api.send(path: "catalog/categories/\(category)/full")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
