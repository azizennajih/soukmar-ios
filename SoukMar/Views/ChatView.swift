import SwiftUI

/// Mirrors soukmar-android's ChatScreen — message list (text/offer/system
/// bubbles), quick replies, offer input, typing indicator, report sheet,
/// cancel-reservation/cancel-offer confirmations.
struct ChatView: View {
    let conversationId: String
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    private var quickReplies: [String] {
        [i18n.t("chat.quick_available"), i18n.t("chat.quick_last_price"), i18n.t("chat.quick_still_interested"), i18n.t("chat.quick_thanks")]
    }

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.loadError || viewModel.conversation == nil {
                Text("Conversation introuvable.").foregroundStyle(.secondary)
            } else {
                content
            }
        }
        .navigationTitle(viewModel.partnerName())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.conversation != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.reportOpen = true
                    } label: {
                        Image(systemName: "flag")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.reportOpen) {
            ReportSheetChat(viewModel: viewModel)
        }
        .alert("\(i18n.t("chat.cancel_reservation")) ?", isPresented: $viewModel.confirmCancelReservation) {
            Button("Confirmer", role: .destructive) { viewModel.confirmCancelReservationAction() }
            Button(i18n.t("chat.cancel"), role: .cancel) { viewModel.dismissCancelReservation() }
        } message: {
            Text("L'annonce redevient active.")
        }
        .alert("Annuler votre offre ?", isPresented: Binding(
            get: { viewModel.confirmCancelOfferId != nil },
            set: { if !$0 { viewModel.dismissCancelOffer() } }
        )) {
            Button("Confirmer", role: .destructive) { viewModel.confirmCancelOffer() }
            Button(i18n.t("chat.cancel"), role: .cancel) { viewModel.dismissCancelOffer() }
        }
        .task { viewModel.load(id: conversationId) }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if viewModel.listingStatus == "RESERVED" {
                HStack {
                    Text("🔒 \(i18n.t("chat.reserved_msg")) \(i18n.t("chat.reserved_word"))").font(.caption).foregroundStyle(Color.soukmarGold)
                    Spacer()
                    Button(i18n.t("chat.cancel")) { viewModel.requestCancelReservation() }.font(.caption)
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Color.soukmarGoldLight)
            }

            if viewModel.reportSubmitted {
                Text("✅ Signalement envoyé, merci.")
                    .font(.caption).foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal).padding(.vertical, 4)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.messages) { msg in
                            messageRow(msg).id(msg.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if viewModel.showOfferInput {
                HStack {
                    Text("💰")
                    TextField("Montant en MAD", text: $viewModel.offerAmount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("chat.send_offer")) { viewModel.sendOffer() }
                        .disabled(viewModel.offerAmount.isEmpty)
                    Button(i18n.t("chat.cancel")) { viewModel.showOfferInput = false }
                }
                .padding()
                .background(Color.soukmarPrimaryLight)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickReplies, id: \.self) { reply in
                        Button(reply) { viewModel.useQuickReply(reply) }
                            .font(.caption)
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal).padding(.vertical, 6)
            }

            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    viewModel.showOfferInput.toggle()
                } label: {
                    Text("💰").font(.title3)
                }
                TextField(i18n.t("chat.placeholder"), text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onChange(of: viewModel.messageText) { _ in viewModel.onTyping() }
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.soukmarTextMuted : Color.soukmarPrimary)
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func messageRow(_ msg: MessageDto) -> some View {
        if viewModel.isSystem(msg) {
            systemMessageRow(msg)
        } else if viewModel.isOffer(msg) {
            offerBubble(msg)
        } else {
            textBubble(msg)
        }
    }

    private func systemMessageRow(_ msg: MessageDto) -> some View {
        HStack {
            Spacer()
            Text(msg.content)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            Spacer()
        }
    }

    private func textBubble(_ msg: MessageDto) -> some View {
        let mine = viewModel.isMine(msg)
        return VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            Text(formatMsgTime(msg.createdAt)).font(.caption2).foregroundStyle(.secondary)
            Text(msg.content)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(mine ? Color.soukmarPrimary : Color(.secondarySystemBackground))
                .foregroundStyle(mine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: 280, alignment: mine ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private func offerBubble(_ msg: MessageDto) -> some View {
        let mine = viewModel.isMine(msg)
        return VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
            Text(formatMsgTime(msg.createdAt)).font(.caption2).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("💰 \(i18n.t("chat.offer_price"))").font(.caption.weight(.semibold)).foregroundStyle(Color.soukmarGold)
                if let amount = msg.offerAmount {
                    let (amountText, _) = formatPriceParts(amount)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(amountText).font(.title3.bold())
                        Text(i18n.t("common.mad")).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                offerStatusLabel(msg, mine: mine)
                if viewModel.canRespond(msg) {
                    HStack(spacing: 8) {
                        Button("✅ \(i18n.t("chat.accept"))") { viewModel.respondOffer(msg, status: "ACCEPTED") }
                            .buttonStyle(.borderedProminent).tint(.green).font(.caption)
                        Button("❌ \(i18n.t("chat.reject"))") { viewModel.respondOffer(msg, status: "REJECTED") }
                            .buttonStyle(.borderedProminent).tint(.red).font(.caption)
                    }
                }
                if viewModel.canCancel(msg) {
                    Button("🚫 \(i18n.t("chat.cancel_offer"))") { viewModel.requestCancelOffer(msg) }
                        .buttonStyle(.bordered).font(.caption)
                }
            }
            .padding(12)
            .background(Color.soukmarGoldLight)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.soukmarGold, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 260, alignment: mine ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    @ViewBuilder
    private func offerStatusLabel(_ msg: MessageDto, mine: Bool) -> some View {
        switch msg.offerStatus {
        case "PENDING": Text("⏳ \(i18n.t("chat.pending"))").font(.caption2).foregroundStyle(.secondary)
        case "ACCEPTED": Text("✅ \(i18n.t("chat.accepted"))").font(.caption2).foregroundStyle(.green)
        case "REJECTED": Text(mine ? "🚫 \(i18n.t("chat.cancelled"))" : "❌ \(i18n.t("chat.rejected"))").font(.caption2).foregroundStyle(.red)
        default: EmptyView()
        }
    }

    private func formatMsgTime(_ iso: String) -> String {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso8601.date(from: iso)
        if date == nil {
            iso8601.formatOptions = [.withInternetDateTime]
            date = iso8601.date(from: iso)
        }
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct ReportSheetChat: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pourquoi signalez-vous cette personne ?").font(.headline)
                if let error = viewModel.reportError {
                    ErrorBanner(message: error)
                }
                TextField("Décrivez le problème (10 caractères min.)", text: $viewModel.reportReason, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
                Button {
                    viewModel.submitReport()
                } label: {
                    if viewModel.reportSubmitting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text(i18n.t("report.submit")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .disabled(viewModel.reportSubmitting)
                Spacer()
            }
            .padding()
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(i18n.t("chat.cancel")) { viewModel.cancelReport() }
                }
            }
        }
    }
}
