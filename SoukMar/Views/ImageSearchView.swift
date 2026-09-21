import SwiftUI
import PhotosUI

/// Mirrors Web's ImageSearchComponent — pick a photo (from the library here;
/// Web also allows a direct file input from the navbar's camera icon),
/// upload it to the dedicated search-by-image endpoint, show a preview +
/// loading state, then either a results grid (reusing ListingCardView, same
/// shape as the regular feed) or an empty state.
struct ImageSearchView: View {
    var onOpenListing: (String) -> Void

    @StateObject private var viewModel = ImageSearchViewModel()
    @State private var photoItem: PhotosPickerItem?
    @ObservedObject private var i18n = I18nRepository.shared

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    if let data = viewModel.previewData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(i18n.t("image_search.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(i18n.t("image_search.pick_btn"), systemImage: "camera")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)

                if viewModel.loading {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(i18n.t("image_search.loading")).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                } else if let error = viewModel.errorMessage {
                    ErrorBanner(message: error).padding(.horizontal, 12)
                } else if viewModel.searched {
                    if viewModel.results.isEmpty {
                        emptyResultsState
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(i18n.t("image_search.results_count")) (\(viewModel.results.count))")
                                .font(.headline)
                                .padding(.horizontal, 12)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(viewModel.results) { listing in
                                    Button {
                                        onOpenListing(listing.id)
                                    } label: {
                                        ListingCardView(listing: listing)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(i18n.t("image_search.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.runSearch(data: data)
                }
                photoItem = nil
            }
        }
    }

    private var emptyResultsState: some View {
        VStack(spacing: 8) {
            Text("🔍").font(.system(size: 40))
            Text(i18n.t("image_search.no_results")).font(.title3.bold())
            Text(i18n.t("image_search.no_results_sub"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

#Preview {
    NavigationStack { ImageSearchView(onOpenListing: { _ in }) }
}
