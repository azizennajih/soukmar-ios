import SwiftUI

/// Mirrors soukmar-android's NotificationsScreen — the in-app notification
/// list, fully functional. Real push delivery is intentionally not wired up:
/// it needs both the Push Notifications capability (requires the paid Apple
/// Developer Program membership, not set up yet — see CLAUDE.md) and a
/// backend APNs integration (the backend currently only speaks FCM, and
/// even that's behind a placeholder Firebase project on the Android side).
/// Same "structurally ready, no real credentials yet" situation Android
/// documented for its own Firebase setup.
struct NotificationsView: View {
    var onOpenChat: (String) -> Void
    var onOpenListing: (String) -> Void
    var onOpenProfil: () -> Void

    @StateObject private var viewModel = NotificationsViewModel()

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.notifications.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.notifications) { notification in
                            NotificationRow(notification: notification) {
                                viewModel.markRead(notification)
                                route(notification)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.hasUnread {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tout marquer comme lu") { viewModel.markAllRead() }
                        .font(.caption)
                }
            }
        }
        .task { viewModel.load() }
    }

    private func route(_ n: NotificationDto) {
        switch n.type {
        case "NEW_INQUIRY", "NEW_REPLY", "NEW_MESSAGE":
            if let conversationId = n.conversationId { onOpenChat(conversationId) }
        case "NEW_REVIEW":
            onOpenProfil()
        case "SAVED_SEARCH_MATCH":
            if let listingId = n.listingId { onOpenListing(listingId) }
        default:
            break // REPORT_RESOLVED and anything else: stay put
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🔔").font(.system(size: 40))
            Text("Aucune notification").font(.title3.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct NotificationRow: View {
    let notification: NotificationDto
    let onOpen: () -> Void

    private var template: String {
        let name = notification.actorName ?? ""
        switch notification.type {
        case "NEW_INQUIRY": return "Vous avez reçu une nouvelle demande de \(name)."
        case "NEW_REPLY": return "\(name) a répondu à votre demande."
        case "NEW_MESSAGE": return "Vous avez reçu un nouveau message de \(name)."
        case "NEW_REVIEW": return "\(name) vous a laissé une évaluation."
        case "SAVED_SEARCH_MATCH": return "Nouvelle annonce pour votre recherche « \(name) »."
        case "REPORT_RESOLVED": return "Votre signalement a été examiné par notre équipe."
        default: return "Nouvelle notification."
        }
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 10) {
                if !notification.isRead {
                    Circle().fill(Color.soukmarPrimary).frame(width: 8, height: 8).padding(.top, 5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(template)
                        .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let title = notification.listingTitle {
                        Text("📌 \(title)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(timeAgo(notification.createdAt)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(notification.isRead ? Color(.secondarySystemBackground) : Color.soukmarPrimaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { NotificationsView(onOpenChat: { _ in }, onOpenListing: { _ in }, onOpenProfil: {}) }
}
