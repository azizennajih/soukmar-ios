import SwiftUI

/// Mirrors soukmar-android's SavedSearchesScreen — list of saved searches
/// with a summary line (category/city/price range), tap to reopen in
/// ListingsView, swipe/× to delete.
struct SavedSearchesView: View {
    var onOpenSearch: (String) -> Void

    @StateObject private var viewModel = SavedSearchesViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.searches.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.searches) { search in
                            SavedSearchRow(search: search, onOpen: { onOpenSearch(search.id) }, onDelete: { viewModel.remove(search.id) })
                        }
                    }
                    .padding(12)
                }
            }
        }
        .navigationTitle("\(i18n.t("saved_searches.title")) (\(viewModel.searches.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🔔").font(.system(size: 40))
            Text(i18n.t("saved_searches.empty")).font(.title3.bold())
            Text(i18n.t("saved_searches.empty_sub"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct SavedSearchRow: View {
    let search: SavedSearchDto
    let onOpen: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var i18n = I18nRepository.shared

    private var cat: CategoryConfig? { search.category.flatMap(categoryConfig) }

    private var meta: [String] {
        var parts: [String] = []
        if let cat { parts.append("\(cat.emoji) \(i18n.tCatalog("cats.\(cat.value)", code: cat.value))") }
        if let city = search.city { parts.append("📍 \(city)") }
        if search.minPrice != nil || search.maxPrice != nil {
            let min = search.minPrice.map(Self.formatPlain) ?? "0"
            let max = search.maxPrice.map(Self.formatPlain) ?? "∞"
            parts.append("\(min)–\(max) \(i18n.t("common.mad"))")
        }
        return parts
    }

    var body: some View {
        Button(action: onOpen) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(search.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if !meta.isEmpty {
                        Text(meta.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private static func formatPlain(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

#Preview {
    NavigationStack { SavedSearchesView(onOpenSearch: { _ in }) }
}
