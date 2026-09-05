import Foundation

/// Mirrors soukmar-android's ChatListViewModel.
@MainActor
final class ChatListViewModel: ObservableObject {
    @Published private(set) var conversations: [ConversationDto] = []
    @Published private(set) var loading = true
    private(set) var currentUserId: String?

    private let chatRepository = ChatRepository.shared

    func load() {
        Task {
            loading = true
            currentUserId = TokenStore.shared.cachedUser?.id
            if let token = TokenStore.shared.token {
                ChatSocketManager.shared.connect(token: token)
            }
            switch await chatRepository.getConversations() {
            case .success(let data):
                conversations = data
            case .failure:
                break // empty list is a fine fallback for the list screen
            }
            loading = false
        }
    }
}
