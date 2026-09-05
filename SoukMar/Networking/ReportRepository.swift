import Foundation

/// Mirrors soukmar-android's ReportRepository — POST /api/reports.
final class ReportRepository {
    static let shared = ReportRepository()
    private let api = APIClient.shared

    func submit(reportedId: String, listingId: String?, reason: String) async -> Result<ReportRecordDto, APIError> {
        do {
            let response: ReportRecordDto = try await api.send(
                path: "reports", method: "POST",
                body: ReportRequest(reportedId: reportedId, listingId: listingId, reason: reason)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
