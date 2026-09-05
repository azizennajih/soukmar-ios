import Foundation

/// Mirrors soukmar-android's AdminViewModel — moderation queue with a
/// default "PENDING" filter, resolve/dismiss actions with an optional note.
@MainActor
final class AdminViewModel: ObservableObject {
    @Published private(set) var reports: [AdminReportDto] = []
    @Published private(set) var loading = true
    @Published private(set) var loadError = false

    @Published var filter = "PENDING"

    @Published private(set) var actionTarget: AdminReportDto?
    @Published private(set) var actionStatus: String?
    @Published var actionNote = ""
    @Published private(set) var actionSubmitting = false

    private let adminRepository = AdminRepository.shared

    var filteredReports: [AdminReportDto] {
        filter == "ALL" ? reports : reports.filter { $0.status == filter }
    }

    func countFor(_ status: String) -> Int {
        status == "ALL" ? reports.count : reports.filter { $0.status == status }.count
    }

    func load() {
        Task {
            loading = true
            loadError = false
            switch await adminRepository.getReports() {
            case .success(let data):
                reports = data
            case .failure:
                loadError = true
            }
            loading = false
        }
    }

    func openAction(_ report: AdminReportDto, status: String) {
        actionTarget = report
        actionStatus = status
        actionNote = ""
    }

    func cancelAction() {
        actionTarget = nil
        actionStatus = nil
        actionNote = ""
    }

    func confirmAction() {
        guard let report = actionTarget, let status = actionStatus, !actionSubmitting else { return }
        actionSubmitting = true
        Task {
            switch await adminRepository.updateReport(id: report.id, status: status, adminNote: actionNote) {
            case .success(let updated):
                // The PATCH response has no reporter/reported/listing
                // includes (only GET /reports/admin does) — merge just the
                // changed fields into the already-loaded row, or those refs
                // go blank.
                if let index = reports.firstIndex(where: { $0.id == report.id }) {
                    reports[index].status = updated.status
                    reports[index].adminNote = updated.adminNote
                    reports[index].resolvedAt = updated.resolvedAt
                }
                actionTarget = nil
                actionStatus = nil
                actionNote = ""
            case .failure:
                break // leave the dialog open so the admin can retry
            }
            actionSubmitting = false
        }
    }
}
