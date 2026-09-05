import SwiftUI

/// Mirrors soukmar-android's FavorisScreen — 2-column grid of favorited
/// listings with a heart overlay to remove directly from the grid.
struct FavorisView: View {
    var onOpenListing: (String) -> Void
    var onBrowse: () -> Void

    @StateObject private var viewModel = FavorisViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.listings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.listings) { listing in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    onOpenListing(listing.id)
                                } label: {
                                    ListingCardView(listing: listing)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.removeFavorite(listing.id)
                                } label: {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.soukmarPrimary)
                                        .padding(6)
                                        .background(.white.opacity(0.9))
                                        .clipShape(Circle())
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .navigationTitle("\(i18n.t("mes_favoris.title")) (\(viewModel.listings.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🤍").font(.system(size: 40))
            Text(i18n.t("mes_favoris.empty")).font(.title3.bold())
            Text(i18n.t("mes_favoris.empty_sub"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(i18n.t("mes_favoris.browse_btn"), action: onBrowse)
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

#Preview {
    NavigationStack { FavorisView(onOpenListing: { _ in }, onBrowse: {}) }
}
