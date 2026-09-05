import SwiftUI

/// A conversation id pushed onto the shared NavigationPath — a dedicated
/// Hashable wrapper rather than a bare String, since HomeView's stack
/// already routes bare Strings to listing detail (see HomeView's
/// navigationDestination(for:) registrations).
struct ConversationRoute: Hashable {
    let conversationId: String
}

/// Mirrors soukmar-android's ChatListScreen.
struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                List(viewModel.conversations) { conv in
                    NavigationLink(value: ConversationRoute(conversationId: conv.id)) {
                        ConversationRow(conv: conv, myId: viewModel.currentUserId)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("💬").font(.system(size: 40))
            Text("Aucune conversation").font(.title3.bold())
            Text("Contactez un vendeur depuis une annonce pour démarrer une discussion.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ConversationRow: View {
    let conv: ConversationDto
    let myId: String?

    private var name: String { conv.partnerName(myId: myId) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.soukmarPrimary)
                .frame(width: 48, height: 48)
                .overlay(Text(name.prefix(1).uppercased()).foregroundStyle(.white).fontWeight(.bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).fontWeight(.semibold).lineLimit(1)
                Text(conv.listing.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(lastMessagePreview).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var lastMessagePreview: String {
        guard let last = conv.messages.first else { return "Aucun message" }
        if last.type == "OFFER" {
            let amount = last.offerAmount.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
            return "Offre: \(amount) MAD"
        }
        return String(last.content.prefix(40))
    }
}

#Preview {
    NavigationStack { ChatListView() }
}
