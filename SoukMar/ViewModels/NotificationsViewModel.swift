import Foundation

/// Mirrors soukmar-android's NotificationsViewModel.
@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [NotificationDto] = []
    @Published private(set) var loading = true

    private let notificationRepository = NotificationRepository.shared

    var hasUnread: Bool { notifications.contains { !$0.isRead } }

    func load() {
        Task {
            loading = true
            switch await notificationRepository.getAll() {
            case .success(let data):
                notifications = data
            case .failure:
                break // keep whatever list was already shown
            }
            loading = false
        }
    }

    /// Optimistically marks read locally, then confirms with the backend.
    func markRead(_ notification: NotificationDto) {
        guard !notification.isRead else { return }
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
        Task { _ = await notificationRepository.markRead(id: notification.id) }
    }

    func markAllRead() {
        guard hasUnread else { return }
        for index in notifications.indices { notifications[index].isRead = true }
        Task { _ = await notificationRepository.markAllRead() }
    }
}
