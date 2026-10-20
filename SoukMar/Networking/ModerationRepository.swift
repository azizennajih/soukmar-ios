import Foundation

/// Outcome of a staff decision: the server answers 409 when another reviewer decided first.
enum DecisionOutcome {
    case done(emailStatus: String?)
    case conflict
    case reasonInvalid
    case failed(String)
}

/// Mirrors soukmar-android's ModerationRepository — the staff API of the listing review workflow.
final class ModerationRepository {
    static let shared = ModerationRepository()
    private let api = APIClient.shared

    private func fail<T>(_ error: Error) -> Result<T, APIError> {
        if let apiError = error as? APIError { return .failure(apiError) }
        return .failure(.network(error.localizedDescription))
    }

    func summary() async -> Result<ModerationSummaryDto, APIError> {
        do {
            let response: ModerationSummaryDto = try await api.send(path: "admin/moderation/summary")
            return .success(response)
        } catch {
            return fail(error)
        }
    }

    func queue(status: String, country: String, category: String, query: String, sort: String, page: Int) async -> Result<ModerationQueueDto, APIError> {
        var params: [String: String] = ["status": status, "sort": sort, "page": String(page), "limit": "20"]
        if !country.isEmpty { params["country"] = country }
        if !category.isEmpty { params["category"] = category }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { params["q"] = q }
        do {
            let response: ModerationQueueDto = try await api.send(path: "admin/moderation/listings", query: params)
            return .success(response)
        } catch {
            return fail(error)
        }
    }

    func detail(id: String) async -> Result<ModerationDetailDto, APIError> {
        do {
            let response: ModerationDetailDto = try await api.send(path: "admin/moderation/listings/\(id)")
            return .success(response)
        } catch {
            return fail(error)
        }
    }

    /// `action` is the URL form: approve | reject | request-changes | suspend | requeue.
    func decide(id: String, action: String, reason: String?, allowResubmit: Bool?, expectedStatus: String) async -> DecisionOutcome {
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ModerationDecisionRequest(
            reason: (trimmed?.isEmpty ?? true) ? nil : trimmed,
            allowResubmit: allowResubmit,
            expectedStatus: expectedStatus
        )
        do {
            let result = try await api.sendRaw(path: "admin/moderation/listings/\(id)/\(action)", method: "POST", body: body)
            switch result.status {
            case 200..<300:
                let parsed = try? JSONDecoder().decode(ModerationDecisionResponseDto.self, from: result.data)
                return .done(emailStatus: parsed?.event?.emailStatus)
            case 409: return .conflict
            case 400: return .reasonInvalid
            default:
                let parsed = try? JSONDecoder().decode(ApiErrorDto.self, from: result.data)
                return .failed(parsed?.error ?? "Une erreur est survenue.")
            }
        } catch let error as APIError {
            if case .network(let message) = error { return .failed(message) }
            return .failed("Une erreur est survenue.")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// True when the mail went out this time.
    func resendMail(eventId: String) async -> Result<Bool, APIError> {
        do {
            let response: ModerationResendResponseDto = try await api.send(
                path: "admin/moderation/events/\(eventId)/resend-email", method: "POST", body: ModerationEmptyBody()
            )
            return .success(response.ok ?? false)
        } catch {
            return fail(error)
        }
    }
}

private struct ModerationEmptyBody: Encodable {}
