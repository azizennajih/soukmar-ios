import SwiftUI

/// Mirrors soukmar-android's FavorisScreen — 2-column grid of favorited
/// listings with a heart overlay to remove directly from the grid.
struct FavorisView: View {
    var onOpenListing: (String) -> Void
    var onBrowse: () -> Void

    @StateObject private var viewModel = FavorisViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.md, alignment: .top)]

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.listings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Spacing.md) {
                        ForEach(viewModel.listings) { listing in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    onOpenListing(listing.id)
                                } label: {
                                    ListingCardView(listing: listing, showFavorite: false)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.removeFavorite(listing.id)
                                } label: {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.soukmarPrimary)
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.92))
                                        .clipShape(Circle())
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel(i18n.t("listing.fav_remove"))
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
        }
        .navigationTitle("\(i18n.t("mes_favoris.title")) (\(viewModel.listings.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "heart",
            title: i18n.t("mes_favoris.empty"),
            subtitle: i18n.t("mes_favoris.empty_sub"),
            actionLabel: i18n.t("mes_favoris.browse_btn"),
            onAction: onBrowse
        )
    }
}

#Preview {
    NavigationStack { FavorisView(onOpenListing: { _ in }, onBrowse: {}) }
}
