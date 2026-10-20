import Foundation

let MODERATION_REASON_MIN = 5
let MODERATION_REASON_MAX = 1000

/// Mirrors soukmar-android's ModerationViewModel — review area for listings. The server enforces every rule, this only
/// drives the screens.
@MainActor
final class ModerationViewModel: ObservableObject {
    @Published private(set) var summary: ModerationSummaryDto?

    // MARK: - queue

    @Published private(set) var items: [ModerationQueueItemDto] = []
    @Published private(set) var total = 0
    @Published private(set) var page = 1
    @Published private(set) var pages = 1
    @Published private(set) var loading = true
    @Published private(set) var loadingMore = false
    @Published private(set) var loadError = false

    @Published private(set) var status = "PENDING"
    @Published private(set) var country = ""
    @Published private(set) var category = ""
    @Published private(set) var sort = "oldest"
    @Published var query = ""

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        loadSummary()
        loadQueue()
    }

    func loadSummary() {
        Task {
            if case .success(let data) = await ModerationRepository.shared.summary() {
                summary = data
            }
        }
    }

    func loadQueue() {
        Task {
            loading = true
            loadError = false
            switch await ModerationRepository.shared.queue(status: status, country: country, category: category, query: query, sort: sort, page: 1) {
            case .success(let data):
                items = data.listings ?? []
                total = data.total ?? 0
                page = data.page ?? 1
                pages = data.pages ?? 1
            case .failure:
                items = []
                loadError = true
            }
            loading = false
        }
    }

    func loadMore() {
        guard !loadingMore, !loading, page < pages else { return }
        Task {
            loadingMore = true
            if case .success(let data) = await ModerationRepository.shared.queue(status: status, country: country, category: category, query: query, sort: sort, page: page + 1) {
                let known = Set(items.map { $0.id })
                items += (data.listings ?? []).filter { !known.contains($0.id) }
                page = data.page ?? page
                pages = data.pages ?? pages
            }
            loadingMore = false
        }
    }

    func selectStatus(_ value: String) {
        status = value
        // Waiting listings are worked oldest first; every other view reads newest first.
        sort = value == "PENDING" ? "oldest" : "newest"
        loadQueue()
    }

    func selectCountry(_ value: String) { country = value; loadQueue() }
    func selectCategory(_ value: String) { category = value; loadQueue() }
    func selectSort(_ value: String) { sort = value; loadQueue() }
    func search() { loadQueue() }

    func resetFilters() {
        status = "PENDING"; country = ""; category = ""; query = ""; sort = "oldest"
        loadQueue()
    }

    // MARK: - detail

    @Published private(set) var detail: ModerationDetailDto?
    @Published private(set) var detailLoading = false

    /// Keys of translated messages to show once.
    @Published private(set) var messageKey: String?
    @Published private(set) var extraMessageKey: String?

    func clearMessage() { messageKey = nil; extraMessageKey = nil }

    func openDetail(_ id: String) {
        Task {
            detailLoading = true
            cancelDecision()
            switch await ModerationRepository.shared.detail(id: id) {
            case .success(let data): detail = data
            case .failure: messageKey = "auth.generic_error"
            }
            detailLoading = false
        }
    }

    func closeDetail() {
        detail = nil
        cancelDecision()
        loadSummary()
        loadQueue()
    }

    // MARK: - decision

    /// URL form of the action waiting for a reason: reject | request-changes | suspend.
    @Published private(set) var reasonAction: String?
    @Published var reason = ""
    @Published var allowResubmit = false
    @Published private(set) var submitting = false
    /// approve / requeue wait for a yes/no confirmation.
    @Published private(set) var confirmAction: String?

    var reasonValid: Bool {
        let length = reason.trimmingCharacters(in: .whitespacesAndNewlines).count
        return length >= MODERATION_REASON_MIN && length <= MODERATION_REASON_MAX
    }

    func startReason(_ action: String) { reasonAction = action; reason = ""; allowResubmit = false }
    func askConfirm(_ action: String) { confirmAction = action }
    func cancelDecision() { reasonAction = nil; confirmAction = nil; reason = ""; allowResubmit = false }

    func submitReason() {
        guard let action = reasonAction, reasonValid else { return }
        decide(action, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines), allowResubmit: action == "reject" ? allowResubmit : nil)
    }

    func confirm() {
        guard let action = confirmAction else { return }
        decide(action, reason: nil, allowResubmit: nil)
    }

    private func decide(_ action: String, reason: String?, allowResubmit: Bool?) {
        guard let d = detail, !submitting else { return }
        Task {
            submitting = true
            let outcome = await ModerationRepository.shared.decide(
                id: d.listing.id, action: action, reason: reason, allowResubmit: allowResubmit, expectedStatus: d.listing.status
            )
            switch outcome {
            case .done(let emailStatus):
                messageKey = "moderation.done_" + action.replacingOccurrences(of: "-", with: "_")
                if emailStatus == "FAILED" { extraMessageKey = "moderation.mail_failed_note" }
                cancelDecision()
                await refreshAfterDecision(d.listing.id)
            case .conflict:
                messageKey = "moderation.conflict"
                cancelDecision()
                await refreshAfterDecision(d.listing.id)
            case .reasonInvalid:
                messageKey = "moderation.reason_required"
            case .failed:
                messageKey = "auth.generic_error"
            }
            submitting = false
        }
    }

    private func refreshAfterDecision(_ id: String) async {
        if case .success(let data) = await ModerationRepository.shared.detail(id: id) {
            detail = data
        }
        loadSummary()
    }

    @Published private(set) var resendingEventId: String?

    func resendMail(_ eventId: String) {
        guard let d = detail, resendingEventId == nil else { return }
        Task {
            resendingEventId = eventId
            switch await ModerationRepository.shared.resendMail(eventId: eventId) {
            case .success(let sent): messageKey = sent ? "moderation.mail_resent_ok" : "moderation.mail_resent_fail"
            case .failure: messageKey = "moderation.mail_not_retryable"
            }
            resendingEventId = nil
            await refreshAfterDecision(d.listing.id)
        }
    }
}
