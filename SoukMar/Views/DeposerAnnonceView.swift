import SwiftUI
import PhotosUI

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
                            .overlay(Text(cat.emoji).font(.title2))
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
                TextField(i18n.t("deposer.label_title"), text: $viewModel.title).textFieldStyle(.roundedBorder)
            }
            labeledField(i18n.t("listing.description")) {
                TextField(i18n.t("deposer.placeholder_desc"), text: $viewModel.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...10)
            }
            labeledField(i18n.t("deposer.label_price")) {
                TextField("Laissez vide pour \"à négocier\"", text: $viewModel.price)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            labeledField(i18n.t("deposer.label_city")) {
                TextField(i18n.t("auth.city"), text: $viewModel.city).textFieldStyle(.roundedBorder)
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
        default:
            TextField("", text: Binding(
                get: { viewModel.attrText[def.code] ?? "" },
                set: { viewModel.attrText[def.code] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

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
                TextField(i18n.t("deposer.label_phone"), text: $viewModel.phone).textFieldStyle(.roundedBorder).keyboardType(.phonePad)
            }
            labeledField(i18n.t("deposer.label_whatsapp")) {
                TextField("Numéro WhatsApp (optionnel)", text: $viewModel.whatsapp).textFieldStyle(.roundedBorder).keyboardType(.phonePad)
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

#Preview {
    NavigationStack { DeposerAnnonceView(onPublished: { _ in }) }
}
