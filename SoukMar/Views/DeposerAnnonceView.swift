import SwiftUI
import PhotosUI

/// A small icon per option makes it much faster to spot the right entry in a
/// 20-item dropdown than reading text alone — scoped to this one attribute
/// (not baked into the shared `attrs.opts.*` strings) since MACHINE_TYPE is
/// the only attribute that needs it. Mirrors web's `machineTypeIcon()`.
private let MACHINE_TYPE_ICONS: [String: String] = [
    "FORKLIFT": "📦", "EXCAVATOR": "⛏️", "BULLDOZER": "🚜", "CRANE": "🏗️",
    "CONCRETE_MIXER": "🧱", "CONCRETE_PUMP": "🚰", "ROAD_ROLLER": "🛣️",
    "PLATE_COMPACTOR": "🚧", "AERIAL_PLATFORM": "🪜", "SCISSOR_LIFT": "⬆️",
    "SCAFFOLDING": "🧗", "GENERATOR": "🔌", "COMPRESSOR": "💨",
    "WELDING_MACHINE": "🔥", "WATER_PUMP": "💧", "CHAINSAW": "🪚",
    "LAWN_MOWER": "🌱", "POWER_TOOLS": "🛠️", "CLEANING_MACHINE": "🧹", "OTHER": "🔩",
]

private func machineTypeIcon(_ code: String) -> String {
    MACHINE_TYPE_ICONS[code].map { "\($0) " } ?? ""
}

/// Mirrors soukmar-android's DeposerAnnonceScreen — 5-step wizard (category
/// → subcategory → details/attributes → photos → contact). Uses SwiftUI's
/// native `PhotosPicker` (iOS 16+) in place of Android's
/// `ActivityResultContracts.GetMultipleContents()`.
struct DeposerAnnonceView: View {
    var editId: String? = nil
    var onPublished: (String) -> Void

    @StateObject private var viewModel = DeposerAnnonceViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @ObservedObject private var i18n = I18nRepository.shared

    /// Mirrors soukmar-android's DEPOSER_STEP_KEYS — DEPOSER_STEPS itself
    /// (DeposerAnnonceViewModel.swift) stays a raw French array out of this
    /// migration's scope, so the i18n keys for the step labels are looked up
    /// by index here instead.
    private let stepKeys = [
        "deposer.step_category", "deposer.step_subcategory", "deposer.step_details",
        "deposer.step_photos", "deposer.step_contact",
    ]

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator

            if viewModel.initLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    stepContent.padding()
                }

                if let error = viewModel.error {
                    ErrorBanner(message: error).padding(.horizontal).padding(.bottom, 8)
                }

                bottomBar
            }
        }
        .navigationTitle(viewModel.isEdit ? i18n.t("deposer.header_title_edit") : i18n.t("deposer.header_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start(editId: editId) }
        .onChange(of: pickerItems) { items in
            Task {
                var newPhotos: [PhotoItem] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        newPhotos.append(PhotoItem(localData: data))
                    }
                }
                viewModel.addPhotos(newPhotos)
                pickerItems = []
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(Array(DEPOSER_STEPS.enumerated()), id: \.offset) { index, _ in
                VStack(spacing: 4) {
                    Circle()
                        .fill(index <= viewModel.step ? Color.soukmarPrimary : Color(.secondarySystemBackground))
                        .frame(width: 8, height: 8)
                    Text(i18n.t(stepKeys[index]))
                        .font(.caption2)
                        .foregroundStyle(index == viewModel.step ? Color.soukmarPrimary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case 0: categoryStep
        case 1: subcategoryStep
        case 2: detailsStep
        case 3: photosStep
        default: contactStep
        }
    }

    private var categoryStep: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(CATEGORIES) { cat in
                Button {
                    viewModel.selectCategory(cat.value)
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(cat.bg)
                            .frame(width: 56, height: 56)
                            .overlay(CategoryIcon(category: cat.value, tint: viewModel.category == cat.value ? Color.soukmarPrimary : cat.fg).frame(width: 26, height: 26))
                            .overlay(
                                Circle().stroke(Color.soukmarPrimary, lineWidth: viewModel.category == cat.value ? 2 : 0)
                            )
                        Text(i18n.tCatalog("cats.\(cat.value)", code: cat.value)).font(.caption).multilineTextAlignment(.center).lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var subcategoryStep: some View {
        if viewModel.loadingSubcats {
            ProgressView()
        } else {
            VStack(spacing: 8) {
                ForEach(viewModel.subcategories) { sub in
                    Button {
                        viewModel.selectSubcategory(sub)
                    } label: {
                        HStack {
                            Text(i18n.tCatalog("subcats.\(sub.code)", code: sub.code))
                            Spacer()
                            if viewModel.subcategoryId == sub.id {
                                Image(systemName: "checkmark").foregroundStyle(Color.soukmarPrimary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledField(i18n.t("deposer.summary_listing_title")) {
                TextField(i18n.t("deposer.placeholder_title_\(viewModel.category.lowercased())"), text: $viewModel.title).textFieldStyle(.roundedBorder)
            }
            labeledField(i18n.t("listing.description")) {
                TextField(i18n.t("deposer.placeholder_desc_\(viewModel.category.lowercased())"), text: $viewModel.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...10)
            }
            // No country field here on purpose — country is centrally
            // controlled by the app-wide CountrySwitcher (Home/Login), never
            // a separate choice within this form. The price label and city
            // source below both derive from viewModel.country, which the
            // ViewModel keeps in live sync with CountryRepository (see
            // start(editId:)'s Combine subscription).
            labeledField("\(i18n.t("deposer.label_price")) (\(viewModel.derivedCurrency))") {
                TextField("Laissez vide pour \"à négocier\"", text: $viewModel.price)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            labeledField(i18n.t("deposer.label_city")) {
                // citiesForCountry empty means the chosen country has no
                // curated list (most of the ~195 countries don't) — falls
                // back to a plain free-text field, exactly like web/Android's
                // fallback (Listing.city is a free string backend-side
                // either way, only without suggestions).
                if viewModel.citiesForCountry.isEmpty {
                    TextField(i18n.t("auth.city"), text: $viewModel.city).textFieldStyle(.roundedBorder)
                } else {
                    CityPickerButton(cities: viewModel.citiesForCountry, selected: $viewModel.city)
                }
            }

            if viewModel.showCondition {
                labeledField(i18n.t("deposer.label_condition")) {
                    HStack(spacing: 8) {
                        ForEach(CONDITION_OPTIONS, id: \.value) { option in
                            Button {
                                viewModel.condition = (viewModel.condition == option.value) ? "" : option.value
                            } label: {
                                Text(option.label)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(viewModel.condition == option.value ? Color.soukmarPrimary : Color(.secondarySystemBackground))
                                    .foregroundStyle(viewModel.condition == option.value ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ForEach(viewModel.attributeDefs) { def in
                labeledField(i18n.tCatalog("attrs.\(def.code)", code: def.code) + (def.required ? " *" : "")) {
                    attributeField(def)
                }
            }
        }
    }

    @ViewBuilder
    private func attributeField(_ def: AttributeDefinitionDto) -> some View {
        if def.code == "PROFESSION" {
            let industry = viewModel.attrText["INDUSTRY"] ?? ""
            let options = JOB_PROFESSIONS_BY_SECTOR[industry] ?? JOB_PROFESSION_CODES
            TextAutocompleteField(
                value: Binding(
                    get: { viewModel.attrText[def.code] ?? "" },
                    set: { viewModel.attrText[def.code] = $0 }
                ),
                options: options,
                labelPrefix: "job_professions."
            )
        } else if def.code == "MACHINE_TYPE" {
            Picker("", selection: Binding(
                get: { viewModel.attrText[def.code] ?? "" },
                set: { viewModel.attrText[def.code] = $0 }
            )) {
                Text("—").tag("")
                ForEach(def.options, id: \.self) { option in
                    Text("\(machineTypeIcon(option))\(i18n.tCatalog("attrs.opts.\(option)", code: option))").tag(option)
                }
            }
            .pickerStyle(.menu)
        } else {
            attributeFieldByType(def)
        }
    }

    @ViewBuilder
    private func attributeFieldByType(_ def: AttributeDefinitionDto) -> some View {
        switch def.type {
        case "BOOLEAN":
            Toggle(isOn: Binding(
                get: { viewModel.attrBool[def.code] ?? false },
                set: { viewModel.attrBool[def.code] = $0 }
            )) { EmptyView() }
            .labelsHidden()
        case "SELECT":
            Picker("", selection: Binding(
                get: { viewModel.attrText[def.code] ?? "" },
                set: { viewModel.attrText[def.code] = $0 }
            )) {
                Text("—").tag("")
                ForEach(def.options, id: \.self) { option in
                    Text(i18n.tCatalog("attrs.opts.\(option)", code: option)).tag(option)
                }
            }
            .pickerStyle(.menu)
        case "NUMBER":
            TextField("", text: Binding(
                get: { viewModel.attrText[def.code] ?? "" },
                set: { viewModel.attrText[def.code] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
        case "MULTI_SELECT":
            VStack(alignment: .leading, spacing: 6) {
                ForEach(def.options, id: \.self) { option in
                    let isOn = (viewModel.attrMulti[def.code] ?? []).contains(option)
                    Button {
                        viewModel.toggleAttrMulti(def.code, option)
                    } label: {
                        HStack {
                            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isOn ? Color.soukmarPrimary : Color(.systemGray3))
                            Text(i18n.tCatalog("attrs.opts.\(option)", code: option))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        case "DATE":
            DatePicker("", selection: Binding(
                get: { Self.isoDateFormatter.date(from: viewModel.attrText[def.code] ?? "") ?? Date() },
                set: { viewModel.attrText[def.code] = Self.isoDateFormatter.string(from: $0) }
            ), displayedComponents: .date)
            .labelsHidden()
        default:
            TextField("", text: Binding(
                get: { viewModel.attrText[def.code] ?? "" },
                set: { viewModel.attrText[def.code] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    /// ISO "yyyy-MM-dd" — matches the backend's `z.iso.date()` expectation
    /// for DATE attributes (no time component).
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(viewModel.photos.count) / \(viewModel.maxPhotos) photos")
                .font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                    photoThumbnail(index: index, photo: photo)
                }

                if viewModel.photos.count < viewModel.maxPhotos {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: viewModel.maxPhotos - viewModel.photos.count,
                        matching: .images
                    ) {
                        VStack {
                            Image(systemName: "plus").font(.title2)
                            Text("Ajouter").font(.caption2)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(index: Int, photo: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = photo.previewImage {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else if let urlString = photo.remoteUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(.secondarySystemBackground)
                        }
                    }
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) {
                if index == 0 {
                    Text(i18n.t("deposer.photo_main"))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.soukmarPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(3)
                }
            }
            .onTapGesture { viewModel.makePrimary(at: index) }

            Button {
                viewModel.removePhoto(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
        }
    }

    private var contactStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledField(i18n.t("deposer.label_phone")) {
                PhoneInputField(value: $viewModel.phone)
            }
            labeledField(i18n.t("deposer.label_whatsapp")) {
                PhoneInputField(value: $viewModel.whatsapp)
            }
            Toggle(i18n.t("deposer.show_phone_toggle"), isOn: $viewModel.showPhone)
            Toggle(i18n.t("deposer.premium_toggle"), isOn: $viewModel.isPremium)
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.soukmarTextMuted)
            content()
        }
    }

    private var bottomBar: some View {
        HStack {
            if viewModel.step > 0 {
                Button(i18n.t("deposer.back")) { viewModel.goBack() }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if viewModel.step < DEPOSER_STEPS.count - 1 {
                Button(i18n.t("deposer.next")) { viewModel.goNext() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .disabled(!viewModel.canNext)
            } else {
                Button {
                    viewModel.publish(onDone: onPublished)
                } label: {
                    if viewModel.loading {
                        ProgressView().tint(.white)
                    } else {
                        Text(viewModel.uploading ? i18n.t("deposer.uploading") : i18n.t("deposer.publish"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .disabled(viewModel.loading)
            }
        }
        .padding()
    }
}

/// Searchable city picker shown only when the currently selected country has
/// a curated city list (`citiesForCountry` non-empty) — mirrors the same
/// `.sheet` + `.searchable()` pattern as `PhoneInputField`'s
/// `CountryPickerSheet`/`CountrySwitcher`'s picker.
private struct CityPickerButton: View {
    let cities: [String]
    @Binding var selected: String
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var pickerOpen = false

    var body: some View {
        Button {
            pickerOpen = true
        } label: {
            HStack {
                Text(selected.isEmpty ? i18n.t("auth.city") : selected)
                    .foregroundStyle(selected.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $pickerOpen) {
            CityPickerSheet(cities: cities, selected: selected) { picked in
                selected = picked
                pickerOpen = false
            }
        }
    }
}

private struct CityPickerSheet: View {
    let cities: [String]
    let selected: String
    let onSelect: (String) -> Void
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return cities }
        return cities.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text(i18n.t("common.no_results")).foregroundStyle(.secondary)
                } else {
                    ForEach(filtered, id: \.self) { city in
                        Button { onSelect(city) } label: {
                            Text(city).foregroundStyle(.primary)
                        }
                        .listRowBackground(city == selected ? Color.soukmarPrimaryLight : Color(.systemBackground))
                    }
                }
            }
            .searchable(text: $query, prompt: i18n.t("common.search"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(i18n.t("common.close")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { DeposerAnnonceView(onPublished: { _ in }) }
}
