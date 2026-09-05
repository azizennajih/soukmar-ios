import Foundation

/// Mirrors soukmar-android's ChatRepository — the REST side of chat
/// (starting/listing conversations, fetching message history). Sending
/// messages/offers has no REST endpoint; that's ChatSocketManager's job.
final class ChatRepository {
    static let shared = ChatRepository()
    private let api = APIClient.shared

    /// Get-or-create the buyer<->listing conversation.
    func startConversation(listingId: String) async -> Result<ConversationDto, APIError> {
        do {
            let response: ConversationDto = try await api.send(
                path: "chat/conversations", method: "POST",
                body: CreateConversationRequest(listingId: listingId)
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getConversations() async -> Result<[ConversationDto], APIError> {
        do {
            let response: [ConversationDto] = try await api.send(path: "chat/conversations")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getMessages(conversationId: String) async -> Result<[MessageDto], APIError> {
        do {
            let response: [MessageDto] = try await api.send(path: "chat/conversations/\(conversationId)/messages")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
