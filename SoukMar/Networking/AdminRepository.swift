import Foundation

/// Mirrors soukmar-android's AdminRepository — GET/PATCH /api/reports/admin,
/// ADMIN (and MODERATOR server-side, though only ADMIN sees the entry point
/// here — same intentional inconsistency Android kept for parity with the
/// web navbar's gating).
final class AdminRepository {
    static let shared = AdminRepository()
    private let api = APIClient.shared

    func getReports() async -> Result<[AdminReportDto], APIError> {
        do {
            let response: [AdminReportDto] = try await api.send(path: "reports/admin")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func updateReport(id: String, status: String, adminNote: String?) async -> Result<AdminReportDto, APIError> {
        do {
            let trimmedNote = adminNote?.trimmingCharacters(in: .whitespacesAndNewlines)
            let response: AdminReportDto = try await api.send(
                path: "reports/admin/\(id)", method: "PATCH",
                body: AdminReportUpdateRequest(status: status, adminNote: (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
