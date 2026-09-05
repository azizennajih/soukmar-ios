import Foundation

/// Mirrors soukmar-android's SavedSearchRepository — CRUD against
/// /api/saved-searches.
final class SavedSearchRepository {
    static let shared = SavedSearchRepository()
    private let api = APIClient.shared

    func getAll() async -> Result<[SavedSearchDto], APIError> {
        do {
            let response: [SavedSearchDto] = try await api.send(path: "saved-searches")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func create(_ body: SavedSearchCreateRequest) async -> Result<SavedSearchDto, APIError> {
        do {
            let response: SavedSearchDto = try await api.send(path: "saved-searches", method: "POST", body: body)
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func delete(id: String) async -> Bool {
        do {
            let _: SuccessDto = try await api.send(path: "saved-searches/\(id)", method: "DELETE")
            return true
        } catch {
            return false
        }
    }
}
