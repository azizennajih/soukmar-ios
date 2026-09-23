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

    // MARK: - ID verifications (free KYC-lite review queue)

    @Published private(set) var idVerifications: [IdVerificationAdminDto] = []
    @Published private(set) var idVerificationsLoading = false
    @Published private(set) var idVerificationsLoaded = false
    @Published private(set) var idVerificationsLoadError = false
    @Published var idVerificationFilter = "PENDING"

    @Published private(set) var idVerificationActionTarget: IdVerificationAdminDto?
    @Published private(set) var idVerificationActionStatus: String?
    @Published var idVerificationActionNote = ""
    @Published private(set) var idVerificationActionSubmitting = false

    var filteredIdVerifications: [IdVerificationAdminDto] {
        idVerificationFilter == "ALL" ? idVerifications : idVerifications.filter { $0.status == idVerificationFilter }
    }

    func countForIdVerification(_ status: String) -> Int {
        status == "ALL" ? idVerifications.count : idVerifications.filter { $0.status == status }.count
    }

    /// Lazy-loaded the first time the "Vérifications" tab is opened, mirrors
    /// the reports queue's own load-on-appear pattern.
    func loadIdVerificationsIfNeeded() {
        guard !idVerificationsLoaded, !idVerificationsLoading else { return }
        Task {
            idVerificationsLoading = true
            idVerificationsLoadError = false
            switch await adminRepository.getIdVerifications() {
            case .success(let data):
                idVerifications = data
                idVerificationsLoaded = true
            case .failure:
                idVerificationsLoadError = true
            }
            idVerificationsLoading = false
        }
    }

    func openIdVerificationAction(_ verification: IdVerificationAdminDto, status: String) {
        idVerificationActionTarget = verification
        idVerificationActionStatus = status
        idVerificationActionNote = ""
    }

    func cancelIdVerificationAction() {
        idVerificationActionTarget = nil
        idVerificationActionStatus = nil
        idVerificationActionNote = ""
    }

    func confirmIdVerificationAction() {
        guard let verification = idVerificationActionTarget, let status = idVerificationActionStatus, !idVerificationActionSubmitting else { return }
        idVerificationActionSubmitting = true
        Task {
            switch await adminRepository.reviewIdVerification(id: verification.id, status: status, adminNote: idVerificationActionNote) {
            case .success(let updated):
                if let index = idVerifications.firstIndex(where: { $0.id == verification.id }) {
                    idVerifications[index].status = updated.status
                    idVerifications[index].adminNote = updated.adminNote
                    idVerifications[index].reviewedAt = updated.reviewedAt
                }
                idVerificationActionTarget = nil
                idVerificationActionStatus = nil
                idVerificationActionNote = ""
            case .failure:
                break // leave the dialog open so the admin can retry
            }
            idVerificationActionSubmitting = false
        }
    }

    // MARK: - Boost requests (paid visibility, see BoostModels.swift)

    @Published private(set) var boostRequests: [BoostRequestDto] = []
    @Published private(set) var boostRequestsLoading = false
    @Published private(set) var boostRequestsLoaded = false
    @Published private(set) var boostRequestsLoadError = false
    @Published var boostRequestFilter = "PENDING"

    @Published private(set) var boostActionTarget: BoostRequestDto?
    @Published private(set) var boostActionStatus: String?
    @Published var boostActionNote = ""
    @Published private(set) var boostActionSubmitting = false

    var filteredBoostRequests: [BoostRequestDto] {
        boostRequestFilter == "ALL" ? boostRequests : boostRequests.filter { $0.status == boostRequestFilter }
    }

    func countForBoostRequest(_ status: String) -> Int {
        status == "ALL" ? boostRequests.count : boostRequests.filter { $0.status == status }.count
    }

    /// Lazy-loaded the first time the "Boosts" tab is opened, mirrors the
    /// id-verifications queue's own load-on-first-open pattern.
    func loadBoostRequestsIfNeeded() {
        guard !boostRequestsLoaded, !boostRequestsLoading else { return }
        Task {
            boostRequestsLoading = true
            boostRequestsLoadError = false
            switch await adminRepository.getBoostRequests() {
            case .success(let data):
                boostRequests = data
                boostRequestsLoaded = true
            case .failure:
                boostRequestsLoadError = true
            }
            boostRequestsLoading = false
        }
    }

    func openBoostAction(_ request: BoostRequestDto, status: String) {
        boostActionTarget = request
        boostActionStatus = status
        boostActionNote = ""
    }

    func cancelBoostAction() {
        boostActionTarget = nil
        boostActionStatus = nil
        boostActionNote = ""
    }

    func confirmBoostAction() {
        guard let request = boostActionTarget, let status = boostActionStatus, !boostActionSubmitting else { return }
        boostActionSubmitting = true
        Task {
            switch await adminRepository.reviewBoostRequest(id: request.id, status: status, adminNote: boostActionNote) {
            case .success(let updated):
                if let index = boostRequests.firstIndex(where: { $0.id == request.id }) {
                    boostRequests[index].status = updated.status
                    boostRequests[index].adminNote = updated.adminNote
                    boostRequests[index].resolvedAt = updated.resolvedAt
                }
                boostActionTarget = nil
                boostActionStatus = nil
                boostActionNote = ""
            case .failure:
                break // leave the dialog open so the admin can retry
            }
            boostActionSubmitting = false
        }
    }

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
