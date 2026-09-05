import SwiftUI

/// Mirrors soukmar-android's ListingsScreen — category/subcategory/condition
/// chips, price range, dynamic EAV attribute filters, and paginated results.
/// Tapping a card pushes ListingDetailView.
struct ListingsView: View {
    @StateObject private var viewModel: ListingsViewModel
    @State private var showFilters = false
    @ObservedObject private var i18n = I18nRepository.shared

    init(initialCategory: String? = nil, savedSearchId: String? = nil) {
        _viewModel = StateObject(wrappedValue: ListingsViewModel(initialCategory: initialCategory, savedSearchId: savedSearchId))
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryChips
            if let selectedCategory = viewModel.selectedCategory, CONDITION_CATEGORIES.contains(selectedCategory) {
                conditionChips
            }
            if TokenStore.shared.isLoggedIn {
                saveSearchSection
            }

            if let error = viewModel.error {
                ErrorBanner(message: error).padding(.horizontal).padding(.top, 8)
            }

            if viewModel.loading && viewModel.listings.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.listings.isEmpty {
                Spacer()
                Text(i18n.t("annonces.empty")).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.listings) { listing in
                            NavigationLink(value: listing.id) {
                                ListingCardView(listing: listing)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if listing.id == viewModel.listings.last?.id {
                                    viewModel.loadMore()
                                }
                            }
                        }
                    }
                    .padding(12)

                    if viewModel.loadingMore {
                        ProgressView().padding(.bottom, 16)
                    }
                }
            }
        }
        .navigationTitle(i18n.t("listing.breadcrumb_listings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            FiltersSheet(viewModel: viewModel)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(i18n.t("nav.search_placeholder"), text: $viewModel.query)
                .textFieldStyle(.plain)
                .onSubmit { viewModel.search() }
                .submitLabel(.search)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipView(label: i18n.t("nav.all"), emoji: nil, selected: viewModel.selectedCategory == nil) {
                    viewModel.setCategory(nil)
                }
                ForEach(CATEGORIES) { cat in
                    ChipView(label: i18n.tCatalog("cats.\(cat.value)", code: cat.value), emoji: cat.emoji, selected: viewModel.selectedCategory == cat.value) {
                        viewModel.setCategory(cat.value)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var saveSearchSection: some View {
        if viewModel.searchSaved {
            Text("✅ \(i18n.t("annonces.search_saved"))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
                .padding(.horizontal)
                .padding(.bottom, 6)
        } else if viewModel.showSaveSearchForm {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField(i18n.t("annonces.save_search_name"), text: $viewModel.newSearchName)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("common.cancel")) { viewModel.cancelSaveSearch() }
                    Button(viewModel.savingSearch ? "…" : i18n.t("common.save")) { viewModel.saveSearch() }
                        .disabled(viewModel.newSearchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.savingSearch)
                }
                if let error = viewModel.saveSearchError {
                    Text(error).font(.caption2).foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        } else {
            Button("🔔 \(i18n.t("annonces.save_search"))") { viewModel.showSaveSearchForm = true }
                .font(.caption.weight(.medium))
                .padding(.horizontal)
                .padding(.bottom, 6)
        }
    }

    private var conditionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CONDITION_OPTIONS, id: \.value) { option in
                    ChipView(label: option.label, emoji: nil, selected: viewModel.selectedCondition == option.value) {
                        viewModel.setCondition(option.value)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

private struct ChipView: View {
    let label: String
    let emoji: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji { Text(emoji) }
                Text(label)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Color.soukmarPrimary : Color(.secondarySystemBackground))
            .foregroundStyle(selected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FiltersSheet: View {
    @ObservedObject var viewModel: ListingsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        NavigationStack {
            Form {
                Section(i18n.t("annonces.price")) {
                    HStack {
                        TextField(i18n.t("annonces.min"), text: $viewModel.minPrice).keyboardType(.numberPad)
                        TextField(i18n.t("annonces.max"), text: $viewModel.maxPrice).keyboardType(.numberPad)
                    }
                }

                if !viewModel.subcategories.isEmpty {
                    Section(i18n.t("annonces.subcategory")) {
                        ForEach(viewModel.subcategories) { sub in
                            Button {
                                viewModel.setSubcategory(sub.id)
                            } label: {
                                HStack {
                                    Text(i18n.tCatalog("subcats.\(sub.code)", code: sub.code))
                                    Spacer()
                                    if viewModel.selectedSubcategoryId == sub.id {
                                        Image(systemName: "checkmark").foregroundStyle(Color.soukmarPrimary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                ForEach(viewModel.filterableAttributes) { attr in
                    Section(i18n.tCatalog("attrs.\(attr.code)", code: attr.code)) {
                        attributeFilter(attr)
                    }
                }
            }
            .navigationTitle(i18n.t("annonces.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(i18n.t("annonces.reset")) {
                        viewModel.clearFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(i18n.t("annonces.apply")) {
                        viewModel.applyAttrRange()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func attributeFilter(_ attr: AttributeDefinitionDto) -> some View {
        switch attr.type {
        case "SELECT":
            ForEach(attr.options, id: \.self) { option in
                Button {
                    viewModel.toggleAttrOption(code: attr.code, option: option)
                } label: {
                    HStack {
                        Text(i18n.tCatalog("attrs.opts.\(option)", code: option))
                        Spacer()
                        if viewModel.attrSelections[attr.code]?.contains(option) == true {
                            Image(systemName: "checkmark").foregroundStyle(Color.soukmarPrimary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        case "BOOLEAN":
            Button {
                viewModel.toggleAttrOption(code: attr.code, option: "true")
            } label: {
                HStack {
                    Text(i18n.t("common.yes"))
                    Spacer()
                    if viewModel.attrSelections[attr.code]?.contains("true") == true {
                        Image(systemName: "checkmark").foregroundStyle(Color.soukmarPrimary)
                    }
                }
            }
            .foregroundStyle(.primary)
        case "NUMBER":
            HStack {
                TextField(i18n.t("annonces.min"), text: Binding(
                    get: { viewModel.attrRanges[attr.code]?.min ?? "" },
                    set: { viewModel.setAttrRange(code: attr.code, min: $0, max: viewModel.attrRanges[attr.code]?.max ?? "") }
                )).keyboardType(.decimalPad)
                TextField(i18n.t("annonces.max"), text: Binding(
                    get: { viewModel.attrRanges[attr.code]?.max ?? "" },
                    set: { viewModel.setAttrRange(code: attr.code, min: viewModel.attrRanges[attr.code]?.min ?? "", max: $0) }
                )).keyboardType(.decimalPad)
            }
        default:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack { ListingsView() }
}
