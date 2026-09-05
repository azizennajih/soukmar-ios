import Foundation

/// Mirrors soukmar-android's ChatViewModel — same offer/message/typing/
/// report/reservation logic against the same Socket.IO event protocol.
@MainActor
final class ChatViewModel: ObservableObject {
    private var conversationId: String?

    @Published private(set) var conversation: ConversationDto?
    @Published private(set) var messages: [MessageDto] = []
    @Published private(set) var loading = true
    @Published private(set) var loadError = false
    private(set) var currentUserId: String?
    @Published private(set) var listingStatus = ""
    @Published private(set) var partnerTyping = false

    @Published var messageText = ""
    @Published var offerAmount = ""
    @Published var showOfferInput = false

    @Published var reportOpen = false
    @Published var reportReason = ""
    @Published private(set) var reportSubmitting = false
    @Published private(set) var reportSubmitted = false
    @Published private(set) var reportError: String?

    @Published var confirmCancelReservation = false
    @Published var confirmCancelOfferId: String?

    private var typingTask: Task<Void, Never>?

    private let chatRepository = ChatRepository.shared
    private let reportRepository = ReportRepository.shared
    private let socketManager = ChatSocketManager.shared

    func load(id: String) {
        if conversationId == id, conversation != nil { return }
        conversationId = id
        Task {
            loading = true
            loadError = false
            currentUserId = TokenStore.shared.cachedUser?.id
            if let token = TokenStore.shared.token {
                socketManager.connect(token: token)
            }

            switch await chatRepository.getConversations() {
            case .success(let data):
                conversation = data.first { $0.id == id }
            case .failure:
                break // messages fetch below still tells us if the conversation is real
            }
            guard conversation != nil else {
                loadError = true
                loading = false
                return
            }
            listingStatus = conversation?.listing.status ?? ""

            switch await chatRepository.getMessages(conversationId: id) {
            case .success(let data):
                messages = data
            case .failure:
                break // start with an empty thread rather than blocking the screen
            }

            socketManager.joinConversation(id)
            observeSocketEvents(id)
            loading = false
        }
    }

    private func observeSocketEvents(_ id: String) {
        socketManager.onEvent = { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                switch event {
                case .newMessage(let message):
                    if message.conversationId == id { self.messages.append(message) }
                case .offerUpdated(let message):
                    self.messages = self.messages.map { $0.id == message.id ? message : $0 }
                case .userTyping(let isTyping):
                    self.partnerTyping = isTyping
                case .listingStatusChanged(let listingId, let status):
                    if listingId == self.conversation?.listingId { self.listingStatus = status }
                }
            }
        }
    }

    func partnerId() -> String? { conversation?.partnerId(myId: currentUserId) }
    func partnerName() -> String { conversation?.partnerName(myId: currentUserId) ?? "" }
    func isMine(_ msg: MessageDto) -> Bool { msg.senderId == currentUserId }
    func isOffer(_ msg: MessageDto) -> Bool { msg.type == "OFFER" }
    func isSystem(_ msg: MessageDto) -> Bool { msg.type == "SYSTEM" }
    func canRespond(_ msg: MessageDto) -> Bool { msg.type == "OFFER" && msg.offerStatus == "PENDING" && !isMine(msg) }
    func canCancel(_ msg: MessageDto) -> Bool { msg.type == "OFFER" && msg.offerStatus == "PENDING" && isMine(msg) }

    func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let conv = conversation, let partner = partnerId(), !text.isEmpty else { return }
        socketManager.sendMessage(conversationId: conv.id, receiverId: partner, listingId: conv.listingId, content: text)
        messageText = ""
        socketManager.emitTyping(conversationId: conv.id, isTyping: false)
        typingTask?.cancel()
    }

    func onTyping() {
        guard let conv = conversation else { return }
        socketManager.emitTyping(conversationId: conv.id, isTyping: true)
        typingTask?.cancel()
        typingTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            socketManager.emitTyping(conversationId: conv.id, isTyping: false)
        }
    }

    func sendOffer() {
        guard let amount = Double(offerAmount), amount > 0,
              let conv = conversation, let partner = partnerId() else { return }
        socketManager.sendOffer(conversationId: conv.id, receiverId: partner, listingId: conv.listingId, amount: amount)
        offerAmount = ""
        showOfferInput = false
    }

    func respondOffer(_ msg: MessageDto, status: String) {
        guard let conv = conversation else { return }
        socketManager.respondOffer(messageId: msg.id, conversationId: conv.id, status: status)
    }

    func requestCancelOffer(_ msg: MessageDto) { confirmCancelOfferId = msg.id }
    func dismissCancelOffer() { confirmCancelOfferId = nil }
    func confirmCancelOffer() {
        guard let conv = conversation, let msgId = confirmCancelOfferId else { return }
        socketManager.cancelOffer(messageId: msgId, conversationId: conv.id, listingId: conv.listingId)
        confirmCancelOfferId = nil
    }

    func requestCancelReservation() { confirmCancelReservation = true }
    func dismissCancelReservation() { confirmCancelReservation = false }
    func confirmCancelReservationAction() {
        guard let conv = conversation else { return }
        socketManager.cancelReservation(conversationId: conv.id, listingId: conv.listingId)
        listingStatus = "ACTIVE"
        confirmCancelReservation = false
    }

    func useQuickReply(_ text: String) { messageText = text }

    func submitReport() {
        guard let conv = conversation, let partner = partnerId() else { return }
        guard reportReason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            reportError = "Merci de décrire la raison en au moins 10 caractères."
            return
        }
        reportSubmitting = true
        reportError = nil
        Task {
            switch await reportRepository.submit(reportedId: partner, listingId: conv.listingId, reason: reportReason.trimmingCharacters(in: .whitespacesAndNewlines)) {
            case .success:
                reportSubmitting = false
                reportSubmitted = true
                reportOpen = false
            case .failure(let error):
                reportSubmitting = false
                reportError = Self.message(for: error)
            }
        }
    }

    func cancelReport() {
        reportOpen = false
        reportError = nil
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return "Une erreur est survenue."
        }
    }
}
