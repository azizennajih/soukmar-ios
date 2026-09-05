import Foundation

/// Mirrors soukmar-android's NotificationRepository — the in-app
/// notifications list, fully functional and independent of push delivery
/// (see NotificationsView.swift's doc comment for why real push isn't wired
/// up yet).
final class NotificationRepository {
    static let shared = NotificationRepository()
    private let api = APIClient.shared

    func getAll() async -> Result<[NotificationDto], APIError> {
        do {
            let response: [NotificationDto] = try await api.send(path: "notifications")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getUnreadCount() async -> Int {
        do {
            let response: UnreadCountResponse = try await api.send(path: "notifications/unread-count")
            return response.count
        } catch {
            return 0
        }
    }

    func markRead(id: String) async -> Bool {
        do {
            // Returns the updated NotificationDto, not {success}; Android's
            // equivalent likewise only checks the HTTP status, not the body.
            let _: NotificationDto = try await api.send(path: "notifications/\(id)/read", method: "PATCH")
            return true
        } catch {
            return false
        }
    }

    func markAllRead() async -> Bool {
        do {
            let _: SuccessDto = try await api.send(path: "notifications/read-all", method: "PATCH")
            return true
        } catch {
            return false
        }
    }
}
