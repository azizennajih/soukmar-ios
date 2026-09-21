import Foundation
import SocketIO

enum ChatSocketEvent {
    case newMessage(MessageDto)
    case offerUpdated(MessageDto)
    case userTyping(Bool)
    case listingStatusChanged(listingId: String, status: String)
    // Masked in-app voice calling (Tranche 23) — same 4 relay events as
    // soukmar-backend's socket.ts, payloads mirror Web's chat.service.ts
    // exactly (sdp/candidate travel as nested dicts matching the browser's
    // native RTCSessionDescriptionInit/RTCIceCandidateInit JSON shape).
    case callOffer(conversationId: String, sdpType: String, sdp: String, fromUserId: String, fromUserName: String)
    case callAnswer(conversationId: String, sdpType: String, sdp: String, fromUserId: String)
    case callIceCandidate(conversationId: String, candidate: String, sdpMid: String?, sdpMLineIndex: Int32, fromUserId: String)
    case callEnd(conversationId: String, fromUserId: String)
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

        socket.on("call_offer") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let conversationId = dict["conversationId"] as? String,
                  let sdpDict = dict["sdp"] as? [String: Any],
                  let sdpType = sdpDict["type"] as? String,
                  let sdp = sdpDict["sdp"] as? String,
                  let fromUserId = dict["fromUserId"] as? String
            else { return }
            let fromUserName = dict["fromUserName"] as? String ?? ""
            self?.onEvent?(.callOffer(conversationId: conversationId, sdpType: sdpType, sdp: sdp, fromUserId: fromUserId, fromUserName: fromUserName))
        }
        socket.on("call_answer") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let conversationId = dict["conversationId"] as? String,
                  let sdpDict = dict["sdp"] as? [String: Any],
                  let sdpType = sdpDict["type"] as? String,
                  let sdp = sdpDict["sdp"] as? String,
                  let fromUserId = dict["fromUserId"] as? String
            else { return }
            self?.onEvent?(.callAnswer(conversationId: conversationId, sdpType: sdpType, sdp: sdp, fromUserId: fromUserId))
        }
        socket.on("call_ice_candidate") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let conversationId = dict["conversationId"] as? String,
                  let candidateDict = dict["candidate"] as? [String: Any],
                  let candidate = candidateDict["candidate"] as? String,
                  let fromUserId = dict["fromUserId"] as? String
            else { return }
            let sdpMid = candidateDict["sdpMid"] as? String
            let sdpMLineIndex = Int32((candidateDict["sdpMLineIndex"] as? Int) ?? 0)
            self?.onEvent?(.callIceCandidate(conversationId: conversationId, candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex, fromUserId: fromUserId))
        }
        socket.on("call_end") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any], let conversationId = dict["conversationId"] as? String else { return }
            let fromUserId = dict["fromUserId"] as? String ?? ""
            self?.onEvent?(.callEnd(conversationId: conversationId, fromUserId: fromUserId))
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

    // MARK: - Masked in-app voice calling (Tranche 23)

    func emitCallOffer(conversationId: String, sdpType: String, sdp: String) {
        let payload: [String: Any] = ["conversationId": conversationId, "sdp": ["type": sdpType, "sdp": sdp]]
        socket?.emit("call_offer", payload)
    }

    func emitCallAnswer(conversationId: String, sdpType: String, sdp: String) {
        let payload: [String: Any] = ["conversationId": conversationId, "sdp": ["type": sdpType, "sdp": sdp]]
        socket?.emit("call_answer", payload)
    }

    func emitCallIceCandidate(conversationId: String, candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        var candidateDict: [String: Any] = ["candidate": candidate, "sdpMLineIndex": sdpMLineIndex]
        if let sdpMid { candidateDict["sdpMid"] = sdpMid }
        let payload: [String: Any] = ["conversationId": conversationId, "candidate": candidateDict]
        socket?.emit("call_ice_candidate", payload)
    }

    func emitCallEnd(conversationId: String) {
        socket?.emit("call_end", ["conversationId": conversationId])
    }
}
