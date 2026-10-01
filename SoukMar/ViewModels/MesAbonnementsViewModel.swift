import Foundation

/// Mirrors soukmar-android's MesAbonnementsViewModel / web's
/// MesAbonnementsComponent — list of followed sellers/buyers. A row is only
/// dropped from the list once the backend confirms the unfollow, not
/// optimistically beforehand (mirrors web's onUnfollow()).
@MainActor
final class MesAbonnementsViewModel: ObservableObject {
    @Published private(set) var users: [FollowedUserDto] = []
    @Published private(set) var loading = true
    @Published private(set) var submittingIds: Set<String> = []

    private let userRepository = UserRepository.shared

    func load() {
        Task {
            loading = true
            switch await userRepository.getFollowing() {
            case .success(let data):
                users = data
            case .failure:
                break // empty list is a fine fallback here
            }
            loading = false
        }
    }

    func unfollow(_ userId: String) {
        guard !submittingIds.contains(userId) else { return }
        submittingIds.insert(userId)
        Task {
            if case .success = await userRepository.unfollowUser(id: userId) {
                users.removeAll { $0.id == userId }
            }
            submittingIds.remove(userId)
        }
    }
}
