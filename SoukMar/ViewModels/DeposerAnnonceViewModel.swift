import Combine
import Foundation
import UIKit

/// A photo either freshly picked from the library (`localData` set) or
/// already stored on the listing being edited (`remoteUrl` set) — mirrors
/// Android's `PhotoItem(remoteUrl, localUri)`.
struct PhotoItem: Identifiable {
    let id = UUID()
    var remoteUrl: String?
    var localData: Data?

    var previewImage: UIImage? { localData.flatMap(UIImage.init(data:)) }
}

let DEPOSER_STEPS = ["Catégorie", "Sous-catégorie", "Détails", "Photos", "Contact"]

/// Mirrors soukmar-android's DeposerAnnonceViewModel — same 5-step wizard,
/// same dynamic EAV attribute handling (NUMBER/TEXT/SELECT travel as plain
/// strings, only BOOLEAN as an actual JSON boolean — see AttrValue), same
/// publish() upload-then-upsert sequencing. Edit mode (`start(editId:)`) is
/// wired here for reuse but has no UI entry point yet — that's Phase 6
/// ("Mes Annonces" → "Modifier"), same order Android built it in.
@MainActor
final class DeposerAnnonceViewModel: ObservableObject {
    @Published var step = 0
    @Published private(set) var loading = false
    @Published private(set) var uploading = false
    @Published private(set) var loadingSubcats = false
    @Published private(set) var success = false
    @Published private(set) var error: String?

    private var editId: String?
    var isEdit: Bool { editId != nil }
    @Published private(set) var initLoading = false

    @Published private(set) var subcategories: [SubcategoryWithAttributesDto] = []
    @Published private(set) var attributeDefs: [AttributeDefinitionDto] = []

    @Published var photos: [PhotoItem] = []
    @Published var isPremium = false

    @Published var category = ""
    @Published var subcategoryId = ""
    @Published var condition = ""
    @Published var title = ""
    @Published var description = ""
    @Published var price = ""
    @Published var city = ""
    /// Not directly settable from this form on purpose — country is
    /// centrally controlled by the app-wide `CountrySwitcher` (Home/Login),
    /// never a separate choice within the create-listing wizard. Kept in
    /// live sync with `CountryRepository.shared.country` for new listings
    /// (see `start(editId:)`'s Combine subscription) so switching country
    /// elsewhere while the wizard is open takes effect immediately. Editing
    /// an existing listing instead preserves its own country (set in
    /// `applyListingToForm`), never re-synced to the currently browsed one.
    @Published private(set) var country = CountryRepository.defaultCountry
    @Published var phone = ""
    @Published var whatsapp = ""
    @Published var showPhone = true
    @Published var attrText: [String: String] = [:]
    @Published var attrBool: [String: Bool] = [:]
    @Published var attrMulti: [String: [String]] = [:]

    private let listingRepository = ListingRepository.shared
    private let catalogRepository = CatalogRepository.shared
    private let uploadRepository = UploadRepository.shared

    private var countryCancellable: AnyCancellable?
    private var countrySyncStarted = false

    var maxPhotos: Int { isPremium ? 20 : 10 }
    var derivedCurrency: String { currencyForCountry(country) }
    /// Towns and villages of the listing's country matching `query` (suggestions for the city fields).
    func searchPlaces(_ query: String) async -> [PlaceHit] {
        await ListingRepository.shared.searchPlaces(country: country, query: query)
    }

    /// Start/destination listings (carpooling, transport…) call the first city the start city.
    var hasDestinationCity: Bool { attributeDefs.contains { $0.code == "DESTINATION_CITY" } }

    /// A destination country is chosen separately for transport; then the destination city stays free text.
    var hasDestinationCountry: Bool { attributeDefs.contains { $0.code == "DESTINATION_COUNTRY" } }

    var citiesForCountry: [String] { country == "MA" ? MOROCCO_CITIES : (CITIES_BY_COUNTRY[country] ?? []) }
    /// Mirrors Android's `showCondition` — hides "Neuf/Occasion" for
    /// subcategories that opt out even within an otherwise physical-goods
    /// category (e.g. Sport & Loisirs' "Offres d'entraînement" coaching).
    var showCondition: Bool {
        guard !category.isEmpty, CONDITION_CATEGORIES.contains(category) else { return false }
        guard let subCode = subcategories.first(where: { $0.id == subcategoryId })?.code else { return true }
        return !NO_CONDITION_SUBCATEGORIES.contains(subCode)
    }

    func start(editId: String?, presetCategory: String? = nil) {
        if let editId, self.editId == nil {
            self.editId = editId
            initLoading = true
            Task {
                switch await listingRepository.getListing(id: editId) {
                case .success(let listing): await applyListingToForm(listing)
                case .failure(let err): error = Self.message(for: err)
                }
                initLoading = false
            }
        } else if editId == nil, !countrySyncStarted {
            countrySyncStarted = true
            checkAiStatus()
            if let presetCategory, category.isEmpty, CATEGORIES.contains(where: { $0.value == presetCategory }) {
                selectCategory(presetCategory)
            }
            // Combine's @Published publisher emits the current value
            // immediately upon subscription, so this single sink covers both
            // the initial default and every later live change — mirrors
            // Android's `snapshotFlow { countryRepository.country }.collect`
            // in DeposerAnnonceViewModel.init(), itself the Compose
            // equivalent of web's constructor effect().
            countryCancellable = CountryRepository.shared.$country
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newCountry in
                    self?.country = newCountry
                    self?.city = ""
                }
        }
    }

    private func applyListingToForm(_ listing: ListingDto) async {
        category = listing.category
        subcategoryId = listing.subcategoryId ?? ""
        condition = listing.condition ?? ""
        title = listing.title
        description = listing.description
        price = listing.price.map(Self.plainNumber) ?? ""
        city = listing.city
        country = listing.country
        phone = listing.phone ?? ""
        whatsapp = listing.whatsapp ?? ""
        showPhone = listing.showPhone ?? true
        attrText = [:]
        attrBool = [:]
        attrMulti = [:]
        // MULTI_SELECT produces one row per selected option (same
        // attributeDefinitionId, several rows) — group by code first so a
        // naive one-row-per-code assignment doesn't silently drop all but the
        // last selected value, same bug Android found and fixed in its own
        // Tranche 3.
        let withCode = listing.attributeValues.filter { !($0.attributeDefinition?.code ?? "").isEmpty }
        let grouped = Dictionary(grouping: withCode) { $0.attributeDefinition!.code }
        for (code, rows) in grouped {
            if rows.first?.attributeDefinition?.type == "MULTI_SELECT" {
                attrMulti[code] = rows.compactMap { $0.valueText }
            } else if let b = rows.first?.valueBoolean {
                attrBool[code] = b
            } else if let n = rows.first?.valueNumber {
                attrText[code] = Self.plainNumber(n)
            } else if let t = rows.first?.valueText {
                attrText[code] = t
            }
        }
        photos = listing.images.map { PhotoItem(remoteUrl: $0) }

        if !listing.category.isEmpty {
            loadingSubcats = true
            switch await catalogRepository.getCategoryFull(category: listing.category) {
            case .success(let data):
                subcategories = data.subcategories
                attributeDefs = subcategories.first { $0.id == listing.subcategoryId }?.attributeDefinitions ?? []
            case .failure:
                break // prefilled form still usable without the filter data
            }
            loadingSubcats = false
        }
        step = 2
    }

    func selectCategory(_ value: String) {
        category = value
        subcategoryId = ""
        attrText = [:]
        attrBool = [:]
        attrMulti = [:]
        attributeDefs = []
        loadingSubcats = true
        Task {
            switch await catalogRepository.getCategoryFull(category: value) {
            case .success(let data):
                subcategories = data.subcategories
                step = subcategories.isEmpty ? 2 : 1
            case .failure:
                subcategories = []
                step = 2
            }
            loadingSubcats = false
        }
    }

    func selectSubcategory(_ sub: SubcategoryWithAttributesDto) {
        subcategoryId = sub.id
        attrText = [:]
        attrBool = [:]
        attrMulti = [:]
        attributeDefs = sub.attributeDefinitions
        step = 2
    }

    // MARK: - AI assistant ("create the listing with AI", mirrors the web component and Android)
    // State lives here, above the wizard steps, so photos, result and edited texts survive back/next.

    /// Which question the assistant is waiting on.
    enum AiConfirm { case editedPreview, formTexts }

    /// false until the server says an AI machine is set up: then the assistant is not shown at all.
    @Published private(set) var aiConfigured = false
    /// nil = not checked yet
    @Published private(set) var aiAvailable: Bool?
    @Published private(set) var aiMaxImages = 6
    @Published private(set) var aiOpen = false
    @Published private(set) var aiLoading = false
    @Published private(set) var aiElapsed = 0
    @Published private(set) var aiError: String?
    @Published private(set) var aiNotice: String?
    @Published private(set) var aiDraft: AiListingDraftDto?
    @Published var aiTitle = ""
    @Published var aiDescription = ""
    /// index into (main suggestion + alternatives)
    @Published var aiSelectedCategory = 0
    @Published private(set) var aiConfirm: AiConfirm?

    /// photos the current draft was made from
    private var aiSignature = ""
    private var aiPendingDraft: AiListingDraftDto?
    private var aiPendingSignature = ""
    /// Title/description as last written by the assistant: tells "still the AI text" from "typed by the user".
    private var aiAppliedTitle = ""
    private var aiAppliedDescription = ""
    private var aiTimer: Task<Void, Never>?

    /// Only freshly picked photos can be analysed (they are still local data).
    private var aiLocalPhotos: [PhotoItem] { Array(photos.filter { $0.localData != nil }.prefix(aiMaxImages)) }
    var aiImages: [Data] { aiLocalPhotos.compactMap { $0.localData } }
    var aiTooManyPhotos: Bool { photos.filter { $0.localData != nil }.count > aiMaxImages }
    private var aiSignatureNow: String { aiLocalPhotos.map { $0.id.uuidString }.joined(separator: "|") }
    var aiPhotosChanged: Bool { aiDraft != nil && aiSignatureNow != aiSignature }

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var aiTitleEdited: Bool {
        guard let draft = aiDraft else { return false }
        return trimmed(aiTitle) != (draft.suggestedTitle ?? "")
    }
    private var aiDescriptionEdited: Bool {
        guard let draft = aiDraft else { return false }
        return trimmed(aiDescription) != (draft.suggestedDescription ?? "")
    }

    func checkAiStatus() {
        Task {
            let status = await uploadRepository.aiStatus()
            aiConfigured = status?.configured == true
            aiAvailable = status?.available == true
            if let max = status?.maxImages, max > 0 { aiMaxImages = max }
        }
    }

    func toggleAi() {
        aiOpen.toggle()
        aiNotice = nil
        if aiOpen, aiAvailable == false { checkAiStatus() }
    }

    func aiAnalyse(force: Bool) {
        let images = aiImages
        guard !images.isEmpty, !aiLoading else { return }
        let signature = aiSignatureNow
        aiLoading = true
        aiError = nil
        aiNotice = nil
        aiElapsed = 0
        aiTimer?.cancel()
        aiTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                self?.aiElapsed += 1
            }
        }
        Task {
            let outcome = await uploadRepository.aiListingDraft(images: images, force: force)
            aiTimer?.cancel()
            aiLoading = false
            switch outcome {
            case .success(let draft):
                aiAvailable = true
                // A new result never silently replaces texts the user edited in the preview.
                if aiTitleEdited || aiDescriptionEdited {
                    aiPendingDraft = draft
                    aiPendingSignature = signature
                    aiConfirm = .editedPreview
                } else {
                    takeAiDraft(draft, signature: signature, replaceTexts: true)
                }
            case .failed(let message, let unavailable):
                if unavailable { aiAvailable = false }
                aiError = message ?? (unavailable
                    ? appText("ai.unavailable", "L'assistant IA est indisponible pour le moment.")
                    : appText("ai.error_generic", "L'analyse des photos a échoué. Réessayez ou continuez manuellement."))
            }
        }
    }

    private func takeAiDraft(_ draft: AiListingDraftDto, signature: String, replaceTexts: Bool) {
        let keepTitle: String? = (!replaceTexts && aiTitleEdited) ? aiTitle : nil
        let keepDescription: String? = (!replaceTexts && aiDescriptionEdited) ? aiDescription : nil
        aiDraft = draft
        aiSignature = signature
        aiSelectedCategory = 0
        aiTitle = keepTitle ?? (draft.suggestedTitle ?? "")
        aiDescription = keepDescription ?? (draft.suggestedDescription ?? "")
    }

    private func aiFormTextsAreMine() -> (title: Bool, description: Bool) {
        let newTitle = trimmed(aiTitle)
        let newDescription = trimmed(aiDescription)
        let titleIsMine = !trimmed(title).isEmpty && title != aiAppliedTitle && title != newTitle
        let descIsMine = !trimmed(description).isEmpty && description != aiAppliedDescription && description != newDescription
        return (titleIsMine, descIsMine)
    }

    /// "Apply suggestion": texts the user wrote in the form are only replaced after a confirmation.
    func aiApply() {
        guard aiDraft != nil, !trimmed(aiTitle).isEmpty, !trimmed(aiDescription).isEmpty else { return }
        let mine = aiFormTextsAreMine()
        if mine.title || mine.description {
            aiConfirm = .formTexts
        } else {
            applyAiDraft(replaceTexts: true)
        }
    }

    func aiResolveConfirm(replace: Bool) {
        guard let kind = aiConfirm else { return }
        aiConfirm = nil
        switch kind {
        case .editedPreview:
            if let draft = aiPendingDraft {
                takeAiDraft(draft, signature: aiPendingSignature, replaceTexts: replace)
            }
        case .formTexts:
            applyAiDraft(replaceTexts: replace)
        }
        aiPendingDraft = nil
    }

    private func applyAiDraft(replaceTexts: Bool) {
        guard let draft = aiDraft else { return }
        let mine = aiFormTextsAreMine()
        let newTitle = trimmed(aiTitle)
        let newDescription = trimmed(aiDescription)
        if replaceTexts || !mine.title { title = newTitle; aiAppliedTitle = newTitle }
        if replaceTexts || !mine.description { description = newDescription; aiAppliedDescription = newDescription }

        let choices = [draft.suggestedCategory] + (draft.alternativeCategories ?? [])
        let choice = choices.indices.contains(aiSelectedCategory) ? choices[aiSelectedCategory] : draft.suggestedCategory
        // Attributes belong to the main suggestion's subcategory; they are dropped if the user picked an alternative.
        let suggested: [String: AiAttrValue] = aiSelectedCategory == 0 ? (draft.attributes ?? [:]) : [:]
        aiOpen = false
        Task {
            let sameSub = category == choice.category && subcategoryId == (choice.subcategoryId ?? "")
            if !sameSub {
                category = choice.category
                subcategoryId = ""
                attrText = [:]
                attrBool = [:]
                attrMulti = [:]
                attributeDefs = []
                loadingSubcats = true
                switch await catalogRepository.getCategoryFull(category: choice.category) {
                case .success(let data): subcategories = data.subcategories
                case .failure: subcategories = []
                }
                loadingSubcats = false
                if let sub = subcategories.first(where: { $0.id == choice.subcategoryId }) {
                    subcategoryId = sub.id
                    attributeDefs = sub.attributeDefinitions
                }
                if !showCondition { condition = "" }
            }
            // Only attributes this subcategory really has, and never over a value the user already entered.
            for def in attributeDefs {
                guard let value = suggested[def.code] else { continue }
                switch value {
                case .bool(let b):
                    if attrBool[def.code] == nil { attrBool[def.code] = b }
                case .text(let s):
                    if (attrText[def.code] ?? "").isEmpty { attrText[def.code] = s }
                }
            }
            // Subcategory still open (the AI only knew the category): let the user choose it, otherwise go to the details.
            step = (!subcategories.isEmpty && subcategoryId.isEmpty) ? 1 : 2
            aiNotice = replaceTexts
                ? appText("ai.applied", "Proposition reprise.")
                : appText("ai.applied_kept_texts", "Vos textes ont été conservés.")
        }
    }

    func goBack() {
        step = (step == 2 && subcategories.isEmpty) ? 0 : step - 1
    }

    func goNext() { step += 1 }

    var canNext: Bool {
        switch step {
        case 0: return !category.isEmpty
        case 1: return !subcategoryId.isEmpty
        case 2:
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            for def in attributeDefs where def.required {
                if def.type == "BOOLEAN" {
                    if attrBool[def.code] == nil { return false }
                } else if def.type == "MULTI_SELECT" {
                    if (attrMulti[def.code] ?? []).isEmpty { return false }
                } else if (attrText[def.code] ?? "").isEmpty {
                    return false
                }
            }
            return true
        default: return true
        }
    }

    func toggleAttrMulti(_ code: String, _ option: String) {
        var current = attrMulti[code] ?? []
        if let idx = current.firstIndex(of: option) {
            current.remove(at: idx)
        } else {
            current.append(option)
        }
        attrMulti[code] = current
    }

    func addPhotos(_ newPhotos: [PhotoItem]) {
        let room = maxPhotos - photos.count
        guard room > 0 else { return }
        photos += newPhotos.prefix(room)
    }

    func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
    }

    /// Promotes a photo to the first slot (cover image) — touch-friendly
    /// stand-in for the web's drag-to-reorder, same as Android.
    func makePrimary(at index: Int) {
        guard index > 0, photos.indices.contains(index) else { return }
        let photo = photos.remove(at: index)
        photos.insert(photo, at: 0)
    }

    func publish(onDone: @escaping (String) -> Void) {
        guard !loading else { return }
        loading = true
        error = nil
        Task {
            let localIndexed = photos.enumerated().filter { $0.element.localData != nil }
            var uploadedUrls: [String] = []
            if !localIndexed.isEmpty {
                uploading = true
                let files = localIndexed.map { (idx, photo) in
                    (data: photo.localData!, filename: "upload_\(idx).jpg", mimeType: "image/jpeg")
                }
                switch await uploadRepository.uploadImages(files, type: "listing") {
                case .success(let urls):
                    uploadedUrls = urls
                case .failure:
                    uploading = false
                    loading = false
                    error = appText("deposer.error_upload", "Le téléchargement des photos a échoué.")
                    return
                }
                uploading = false
            }

            var uploadIdx = 0
            let images: [String] = photos.map { photo in
                if photo.localData != nil {
                    defer { uploadIdx += 1 }
                    return uploadedUrls[uploadIdx]
                }
                return photo.remoteUrl ?? ""
            }

            var attributes: [String: AttrValue] = [:]
            for (code, value) in attrText where !value.isEmpty { attributes[code] = .text(value) }
            for (code, value) in attrBool { attributes[code] = .bool(value) }
            for (code, values) in attrMulti where !values.isEmpty { attributes[code] = .stringArray(values) }

            let body = ListingUpsertRequest(
                title: title,
                description: description,
                price: Double(price),
                category: category,
                subcategoryId: subcategoryId.isEmpty ? nil : subcategoryId,
                condition: condition.isEmpty ? nil : condition,
                city: city,
                country: country,
                images: images,
                phone: phone.isEmpty ? nil : phone,
                whatsapp: whatsapp.isEmpty ? nil : whatsapp,
                showPhone: showPhone,
                attributes: attributes
            )

            let result = editId != nil
                ? await listingRepository.updateListing(id: editId!, body: body)
                : await listingRepository.createListing(body)

            switch result {
            case .success(let listing):
                success = true
                loading = false
                onDone(listing.id)
            case .failure:
                loading = false
                error = appText("deposer.error_publish", "La publication a échoué. Réessayez.")
            }
        }
    }

    private static func plainNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return genericErrorText()
        }
    }
}
