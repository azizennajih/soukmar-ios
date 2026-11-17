import SwiftUI

/// Mirrors soukmar-android's MesAbonnementsScreen / web's "Mes abonnements"
/// page — list of followed sellers/buyers, each row with its own unfollow
/// button.
struct MesAbonnementsView: View {
    var onOpenSeller: (String) -> Void
    var onBrowse: () -> Void

    @StateObject private var viewModel = MesAbonnementsViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.users.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.users) { user in
                            FollowedUserRow(
                                user: user,
                                submitting: viewModel.submittingIds.contains(user.id),
                                onOpen: { onOpenSeller(user.id) },
                                onUnfollow: { viewModel.unfollow(user.id) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .navigationTitle("\(i18n.t("mes_abonnements.title")) (\(viewModel.users.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.badge.plus").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(i18n.t("mes_abonnements.empty")).font(.title3.bold())
            Text(i18n.t("mes_abonnements.empty_sub"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(i18n.t("mes_abonnements.browse_btn"), action: onBrowse)
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct FollowedUserRow: View {
    let user: FollowedUserDto
    let submitting: Bool
    let onOpen: () -> Void
    let onUnfollow: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.soukmarPrimary).frame(width: 48, height: 48)
                        if let imageUrl = user.image, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Text(user.name.prefix(1).uppercased()).foregroundStyle(.white).font(.headline)
                                }
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        } else {
                            Text(user.name.prefix(1).uppercased()).foregroundStyle(.white).font(.headline)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        VerifiedBadge(emailVerified: user.emailVerified, phoneVerified: user.phoneVerified, idVerified: user.idVerified)
                        HStack(spacing: 8) {
                            if let city = user.city {
                                Label(city, systemImage: "mappin").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text("\(user.activeListingsCount) \(i18n.t("seller.listings_title"))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            FollowButton(following: true, submitting: submitting, onToggle: onUnfollow)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack { MesAbonnementsView(onOpenSeller: { _ in }, onBrowse: {}) }
}
