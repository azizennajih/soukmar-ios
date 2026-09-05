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
    @Published var phone = ""
    @Published var whatsapp = ""
    @Published var showPhone = true
    @Published var attrText: [String: String] = [:]
    @Published var attrBool: [String: Bool] = [:]

    private let listingRepository = ListingRepository.shared
    private let catalogRepository = CatalogRepository.shared
    private let uploadRepository = UploadRepository.shared

    var maxPhotos: Int { isPremium ? 20 : 10 }
    var showCondition: Bool { !category.isEmpty && CONDITION_CATEGORIES.contains(category) }

    func start(editId: String?) {
        guard self.editId == nil, let editId else { return }
        self.editId = editId
        initLoading = true
        Task {
            switch await listingRepository.getListing(id: editId) {
            case .success(let listing): await applyListingToForm(listing)
            case .failure(let err): error = Self.message(for: err)
            }
            initLoading = false
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
        phone = listing.phone ?? ""
        whatsapp = listing.whatsapp ?? ""
        showPhone = listing.showPhone ?? true
        attrText = [:]
        attrBool = [:]
        for av in listing.attributeValues {
            guard let code = av.attributeDefinition?.code else { continue }
            if let b = av.valueBoolean {
                attrBool[code] = b
            } else if let n = av.valueNumber {
                attrText[code] = Self.plainNumber(n)
            } else if let t = av.valueText {
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
        attributeDefs = sub.attributeDefinitions
        step = 2
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
                } else if (attrText[def.code] ?? "").isEmpty {
                    return false
                }
            }
            return true
        default: return true
        }
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
                switch await uploadRepository.uploadImages(files) {
                case .success(let urls):
                    uploadedUrls = urls
                case .failure:
                    uploading = false
                    loading = false
                    error = "Le téléchargement des photos a échoué."
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

            let body = ListingUpsertRequest(
                title: title,
                description: description,
                price: Double(price),
                currency: "MAD",
                category: category,
                subcategoryId: subcategoryId.isEmpty ? nil : subcategoryId,
                condition: condition.isEmpty ? nil : condition,
                city: city,
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
                error = "La publication a échoué. Réessayez."
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
        case .decoding: return "Une erreur est survenue."
        }
    }
}
