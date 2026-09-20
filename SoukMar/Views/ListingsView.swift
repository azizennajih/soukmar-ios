import SwiftUI

/// Mirrors soukmar-android's ListingsScreen — category/subcategory/condition
/// chips, price range, dynamic EAV attribute filters, and paginated results.
/// Tapping a card pushes ListingDetailView.
struct ListingsView: View {
    @StateObject private var viewModel: ListingsViewModel
    @State private var showFilters = false
    @State private var viewMode: ViewMode = .list
    @ObservedObject private var i18n = I18nRepository.shared

    private enum ViewMode { case list, map }

    init(initialCategory: String? = nil, savedSearchId: String? = nil, editSearchId: String? = nil) {
        _viewModel = StateObject(wrappedValue: ListingsViewModel(initialCategory: initialCategory, savedSearchId: savedSearchId, editSearchId: editSearchId))
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryChips
            if viewModel.showCondition {
                conditionChips
            }
            accountTypeChips
            if TokenStore.shared.isLoggedIn {
                saveSearchSection
            }

            if let error = viewModel.error {
                ErrorBanner(message: error).padding(.horizontal).padding(.top, 8)
            }

            if !viewModel.listings.isEmpty {
                viewModeToggle
            }

            if viewModel.loading && viewModel.listings.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.listings.isEmpty {
                Spacer()
                Text(i18n.t("annonces.empty")).foregroundStyle(.secondary)
                Spacer()
            } else if viewMode == .map {
                ListingsMapView(listings: viewModel.listings)
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

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(.list, label: i18n.t("annonces.view_list"), icon: "list.bullet")
            toggleButton(.map, label: i18n.t("annonces.view_map"), icon: "map")
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func toggleButton(_ mode: ViewMode, label: String, icon: String) -> some View {
        Button {
            viewMode = mode
        } label: {
            Label(label, systemImage: icon)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(viewMode == mode ? Color.soukmarPrimary : Color(.secondarySystemBackground))
                .foregroundStyle(viewMode == mode ? .white : .primary)
        }
        .buttonStyle(.plain)
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
                ChipView(label: i18n.t("nav.all"), category: nil, selected: viewModel.selectedCategory == nil) {
                    viewModel.setCategory(nil)
                }
                ForEach(CATEGORIES) { cat in
                    ChipView(label: i18n.tCatalog("cats.\(cat.value)", code: cat.value), category: cat.value, selected: viewModel.selectedCategory == cat.value) {
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
            Label(i18n.t("annonces.search_saved"), systemImage: "checkmark.circle.fill")
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
                    Button(viewModel.savingSearch ? "…" : (viewModel.editSearchId != nil ? i18n.t("annonces.update_search") : i18n.t("common.save"))) { viewModel.saveSearch() }
                        .disabled(viewModel.newSearchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.savingSearch)
                }
                if let error = viewModel.saveSearchError {
                    Text(error).font(.caption2).foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        } else {
            Button { viewModel.showSaveSearchForm = true } label: { Label(i18n.t("annonces.save_search"), systemImage: "bell") }
                .font(.caption.weight(.medium))
                .padding(.horizontal)
                .padding(.bottom, 6)
        }
    }

    private var conditionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CONDITION_OPTIONS, id: \.value) { option in
                    ChipView(label: option.label, category: nil, selected: viewModel.selectedCondition == option.value) {
                        viewModel.setCondition(option.value)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var accountTypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipView(label: i18n.t("auth.account_type_private"), category: nil, selected: viewModel.selectedAccountType == "PRIVATE") {
                    viewModel.setAccountType("PRIVATE")
                }
                ChipView(label: i18n.t("auth.account_type_business"), category: nil, selected: viewModel.selectedAccountType == "BUSINESS") {
                    viewModel.setAccountType("BUSINESS")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

private struct ChipView: View {
    let label: String
    let category: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let category {
                    CategoryIcon(category: category, tint: selected ? .white : .primary)
                        .frame(width: 15, height: 15)
                }
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
                Section(i18n.t("deposer.label_country").replacingOccurrences(of: " *", with: "")) {
                    CountrySwitcher(country: viewModel.country) { viewModel.selectCountry($0) }
                }

                Section(i18n.t("annonces.city")) {
                    if viewModel.lat != nil {
                        HStack {
                            Label(i18n.t("annonces.current_location"), systemImage: "location.fill")
                            Spacer()
                            Button {
                                viewModel.clearLocation()
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                        Picker(i18n.t("annonces.radius"), selection: $viewModel.radius) {
                            ForEach(["5", "10", "20", "30", "50", "100", "150", "200"], id: \.self) { r in
                                Text("+\(r) km").tag(r)
                            }
                        }
                        .onChange(of: viewModel.radius) { viewModel.setRadius($0) }
                    } else {
                        Button {
                            viewModel.useCurrentLocation()
                        } label: {
                            if viewModel.locationLoading {
                                HStack { ProgressView(); Text(i18n.t("annonces.use_gps")) }
                            } else {
                                Label(i18n.t("annonces.use_gps"), systemImage: "location")
                            }
                        }
                        .disabled(viewModel.locationLoading)
                        if let locationError = viewModel.locationError {
                            Text(i18n.t(locationError)).font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section(i18n.t("annonces.sort")) {
                    sortRow("", label: i18n.t("annonces.newest"))
                    sortRow("prix_asc", label: i18n.t("annonces.price_asc"))
                    sortRow("prix_desc", label: i18n.t("annonces.price_desc"))
                    if viewModel.lat != nil {
                        sortRow("distance", label: i18n.t("annonces.distance"))
                    }
                }

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

    private func sortRow(_ value: String, label: String) -> some View {
        Button {
            viewModel.setSort(value)
        } label: {
            HStack {
                Text(label)
                Spacer()
                if viewModel.sortBy == value {
                    Image(systemName: "checkmark").foregroundStyle(Color.soukmarPrimary)
                }
            }
        }
        .foregroundStyle(.primary)
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
