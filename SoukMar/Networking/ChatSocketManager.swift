import Foundation
import SocketIO

enum ChatSocketEvent {
    case newMessage(MessageDto)
    case offerUpdated(MessageDto)
    case userTyping(Bool)
    case listingStatusChanged(listingId: String, status: String)
}

/// Thin wrapper around socket.io-client-swift mirroring Android's
/// ChatSocketManager — same event names/payloads as soukmar-backend's
/// socket.ts, since the backend only speaks Socket.IO for chat (no REST
/// endpoints to send a message or respond to an offer).
///
/// Deliberate simplification vs. Android: Android connects/disconnects the
/// socket exactly with the chat-list screen's lifecycle (ViewModel
/// created/cleared). SwiftUI's NavigationStack fires `onDisappear` on a
/// screen the moment something is pushed on top of it too (not just when
/// it's popped), so tying disconnect() to that would drop the connection
/// the instant a conversation is opened. Instead: connect() lazily whenever
/// chat is opened (idempotent — a no-op if already connected), and
/// disconnect() only on logout. socket.io's own reconnection handles
/// backgrounding fine; leaving one JWT-authenticated socket open for the
/// rest of the session is an acceptable tradeoff for a hobby-scale app.
final class ChatSocketManager {
    static let shared = ChatSocketManager()

    private var manager: SocketManager?
    private var socket: SocketIOClient?

    /// Only one screen listens at a time in this app (whichever chat screen
    /// is currently active), unlike Android's SharedFlow which supports
    /// multiple collectors — simpler and sufficient for this app's shape.
    var onEvent: ((ChatSocketEvent) -> Void)?

    private var isConnected: Bool { socket?.status == .connected }

    func connect(token: String) {
        guard !isConnected else { return }
        #if DEBUG
        // iOS Simulator shares the Mac's own localhost, same as APIClient's dev URL.
        let url = URL(string: "http://127.0.0.1:3000")!
        #else
        let url = URL(string: "https://api.soukmar.ma")!
        #endif
        let manager = SocketManager(socketURL: url, config: [.log(false), .compress, .forceWebsockets(true)])
        let socket = manager.defaultSocket
        registerHandlers(on: socket)
        // withPayload: sent as the Socket.IO CONNECT packet payload, which
        // is exactly what the server reads as socket.handshake.auth — NOT
        // a query string (that would be .connectParams, a different field
        // the backend's auth middleware doesn't check).
        socket.connect(withPayload: ["token": token])
        self.manager = manager
        self.socket = socket
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
    }

    private func registerHandlers(on socket: SocketIOClient) {
        socket.on("new_message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any], let message = Self.decodeMessage(dict) else { return }
            self?.onEvent?(.newMessage(message))
        }
        socket.on("offer_updated") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any], let message = Self.decodeMessage(dict) else { return }
            self?.onEvent?(.offerUpdated(message))
        }
        socket.on("user_typing") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            self?.onEvent?(.userTyping(dict["isTyping"] as? Bool ?? false))
        }
        socket.on("listing_status_changed") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any], let listingId = dict["listingId"] as? String else { return }
            self?.onEvent?(.listingStatusChanged(listingId: listingId, status: dict["status"] as? String ?? "ACTIVE"))
        }
    }

    private static func decodeMessage(_ dict: [String: Any]) -> MessageDto? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(MessageDto.self, from: data)
    }

    func joinConversation(_ conversationId: String) {
        socket?.emit("join_conversation", conversationId)
    }

    func sendMessage(conversationId: String, receiverId: String, listingId: String, content: String) {
        let payload: [String: Any] = [
            "conversationId": conversationId, "receiverId": receiverId,
            "listingId": listingId, "content": content,
        ]
        socket?.emit("send_message", payload)
    }

    func sendOffer(conversationId: String, receiverId: String, listingId: String, amount: Double) {
        let payload: [String: Any] = [
            "conversationId": conversationId, "receiverId": receiverId,
            "listingId": listingId, "amount": amount,
        ]
        socket?.emit("send_offer", payload)
    }

    func respondOffer(messageId: String, conversationId: String, status: String) {
        let payload: [String: Any] = ["messageId": messageId, "conversationId": conversationId, "status": status]
        socket?.emit("respond_offer", payload)
    }

    func cancelOffer(messageId: String, conversationId: String, listingId: String) {
        let payload: [String: Any] = ["messageId": messageId, "conversationId": conversationId, "listingId": listingId]
        socket?.emit("cancel_offer", payload)
    }

    func cancelReservation(conversationId: String, listingId: String) {
        let payload: [String: Any] = ["conversationId": conversationId, "listingId": listingId]
        socket?.emit("cancel_reservation", payload)
    }

    func emitTyping(conversationId: String, isTyping: Bool) {
        let payload: [String: Any] = ["conversationId": conversationId, "isTyping": isTyping]
        socket?.emit("typing", payload)
    }
}
