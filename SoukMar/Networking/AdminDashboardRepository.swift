import Foundation

/// Dashboard half of the admin area (overview / listings / users / visitors / revenue / security) — mirrors
/// the dashboard methods of soukmar-android's AdminRepository. `country` nil = every country, like the
/// web's "All countries" scope.
final class AdminDashboardRepository {
    static let shared = AdminDashboardRepository()
    private let api = APIClient.shared

    private func scoped(_ country: String?, _ extra: [String: String] = [:]) -> [String: String] {
        var query = extra
        if let country { query["country"] = country }
        return query
    }

    private func fetch<T: Decodable>(_ path: String, query: [String: String] = [:]) async -> Result<T, APIError> {
        do {
            let response: T = try await api.send(path: path, query: query)
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(genericErrorText()))
        }
    }

    func getAllListings(country: String?) async -> Result<[ListingDto], APIError> {
        let result: Result<ListingsResponseDto, APIError> = await fetch("listings", query: scoped(country, ["limit": "500", "status": "ALL"]))
        return result.map { $0.listings }
    }

    func getUsers(country: String?) async -> Result<[AdminUserDto], APIError> {
        await fetch("admin/users", query: scoped(country))
    }

    func getActivity(country: String?) async -> Result<[AdminActivityDto], APIError> {
        await fetch("admin/activity", query: scoped(country, ["limit": "40"]))
    }

    func getAnalytics(country: String?) async -> Result<AdminAnalyticsDto, APIError> {
        await fetch("admin/analytics", query: scoped(country, ["days": "30"]))
    }

    func getSecurityEvents() async -> Result<[SecurityEventDto], APIError> {
        await fetch("admin/security-events")
    }

    /// Plain 2xx/non-2xx outcome: the answer body is not needed, so it is not decoded.
    private func succeeds<Body: Encodable>(_ path: String, _ method: String, _ body: Body) async -> Bool {
        guard let result = try? await api.sendRaw(path: path, method: method, body: body) else { return false }
        return (200..<300).contains(result.status)
    }

    func setUserRole(id: String, role: String) async -> Bool {
        await succeeds("admin/users/\(id)", "PATCH", AdminUserRoleRequest(role: role))
    }

    func setListingStatus(id: String, status: String) async -> Bool {
        await succeeds("listings/\(id)", "PUT", ListingStatusUpdateRequest(status: status))
    }

    func setListingPremium(id: String, premium: Bool) async -> Bool {
        await succeeds("listings/\(id)", "PUT", ListingPremiumUpdateRequest(isPremium: premium))
    }

    func deleteListing(id: String) async -> Bool {
        await ListingRepository.shared.deleteListing(id: id)
    }
}
