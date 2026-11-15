import SwiftUI
import PhotosUI
import UIKit

/// "Create the listing with AI" (mirrors the web's app-ai-listing-assistant and Android's AiAssistantCard).
/// Sits above the wizard steps, so it stays visible on every step; its state lives in DeposerAnnonceViewModel
/// and survives back/next. The photos are the form's own photo list. Nothing is written into the form before
/// "apply suggestion". Not rendered at all while the server has no AI machine configured.
struct AiAssistantCard: View {
    @ObservedObject var viewModel: DeposerAnnonceViewModel
    @Binding var pickerItems: [PhotosPickerItem]
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        if viewModel.aiConfigured {
            VStack(alignment: .leading, spacing: 0) {
                header
                if let notice = viewModel.aiNotice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                if viewModel.aiOpen {
                    Divider()
                    content.padding(14)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.soukmarGold, lineWidth: 1.5))
            // A new result never silently replaces texts edited in the preview; "apply" never silently
            // replaces a title or description the user wrote in the form.
            .alert(confirmMessage, isPresented: Binding(
                get: { viewModel.aiConfirm != nil },
                set: { if !$0 { viewModel.aiResolveConfirm(replace: false) } }
            )) {
                Button(i18n.t("ai.replace")) { viewModel.aiResolveConfirm(replace: true) }
                Button(i18n.t("ai.keep_mine"), role: .cancel) { viewModel.aiResolveConfirm(replace: false) }
            }
        }
    }

    private var confirmMessage: String {
        viewModel.aiConfirm == .editedPreview ? i18n.t("ai.confirm_overwrite_edit") : i18n.t("ai.confirm_overwrite_form")
    }

    private var header: some View {
        Button {
            viewModel.toggleAi()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("ai.cta")).font(.subheadline.weight(.bold)).foregroundStyle(Color.primary)
                    Text(viewModel.aiDraft != nil && !viewModel.aiOpen ? i18n.t("ai.has_result") : i18n.t("ai.cta_sub"))
                        .font(.caption)
                        .foregroundStyle(Color.soukmarTextMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if viewModel.aiLoading { ProgressView() }
                Image(systemName: viewModel.aiOpen ? "chevron.up" : "chevron.down").foregroundStyle(Color.soukmarGold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.soukmarGoldLight)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.aiAvailable == false {
                notice(i18n.t("ai.unavailable"), warn: true)
                Button(i18n.t("ai.retry_status")) { viewModel.checkAiStatus() }
                    .font(.caption)
                    .foregroundStyle(Color.soukmarPrimary)
            }

            Text(i18n.t("ai.photos_hint")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)

            if !viewModel.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                            thumbnail(index: index, photo: photo)
                        }
                    }
                }
            }

            if viewModel.photos.count < viewModel.maxPhotos {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: viewModel.maxPhotos - viewModel.photos.count,
                    matching: .images
                ) {
                    Label(viewModel.photos.isEmpty ? i18n.t("ai.add_photos") : i18n.t("ai.add_more"), systemImage: "camera")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(Color.primary)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
                }
                .disabled(viewModel.aiLoading)
            }

            if viewModel.aiDraft == nil {
                primaryButton(i18n.t("ai.analyse"), enabled: !viewModel.aiImages.isEmpty && !viewModel.aiLoading && viewModel.aiAvailable != false) {
                    viewModel.aiAnalyse(force: false)
                }
            }
            if viewModel.aiTooManyPhotos {
                Text(i18n.t("ai.max_note", ["n": String(viewModel.aiMaxImages)])).font(.caption).foregroundStyle(Color.soukmarTextMuted)
            }

            if viewModel.aiLoading {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(i18n.t("ai.analysing")) (\(viewModel.aiElapsed) s)").font(.footnote.weight(.semibold))
                        Text(i18n.t("ai.analysing_hint")).font(.caption).foregroundStyle(Color.soukmarTextMuted)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = viewModel.aiError {
                notice(error, warn: false)
            }

            if let draft = viewModel.aiDraft {
                result(draft)
            }

            Button(i18n.t("ai.close")) { viewModel.toggleAi() }
                .font(.footnote)
                .foregroundStyle(Color.soukmarTextMuted)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func result(_ draft: AiListingDraftDto) -> some View {
        resultHead(draft)
        resultTexts(draft)
        resultCategory(draft)
        resultDetails(draft)
        resultActions(draft)
    }

    @ViewBuilder
    private func resultHead(_ draft: AiListingDraftDto) -> some View {
        let confidence = draft.confidence ?? 0
        Divider()
        HStack {
            Text(i18n.t("ai.result_title")).font(.headline)
            Spacer()
            Text("\(i18n.t("ai.confidence")): \(confidenceLabel(confidence))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(confidence >= 0.75 ? Color.green : (confidence >= 0.5 ? Color.soukmarGold : Color.red))
        }
        Text(i18n.t("ai.result_note")).font(.caption).foregroundStyle(Color.soukmarTextMuted)

        if confidence < 0.5 { notice(i18n.t("ai.uncertain"), warn: true) }
        if viewModel.aiPhotosChanged { notice(i18n.t("ai.photos_changed"), warn: true) }
        if draft.cached == true {
            Text(i18n.t("ai.cached")).font(.caption).foregroundStyle(Color.soukmarTextMuted)
        }

        fact(i18n.t("ai.product"), draft.productName ?? "")
    }

    @ViewBuilder
    private func resultTexts(_ draft: AiListingDraftDto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(i18n.t("deposer.label_title"))
            TextField("", text: $viewModel.aiTitle, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.aiTitle) { value in
                    if value.count > 100 { viewModel.aiTitle = String(value.prefix(100)) }
                }
            Text("\(viewModel.aiTitle.count)/100 \(i18n.t("deposer.chars"))").font(.caption2).foregroundStyle(Color.soukmarTextMuted)
        }
        VStack(alignment: .leading, spacing: 4) {
            label(i18n.t("deposer.label_desc"))
            TextField("", text: $viewModel.aiDescription, axis: .vertical)
                .lineLimit(5...12)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func resultCategory(_ draft: AiListingDraftDto) -> some View {
        let choices = [draft.suggestedCategory] + (draft.alternativeCategories ?? [])
        label(choices.count > 1 ? i18n.t("ai.category_choose") : i18n.t("ai.category"))
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let selected = viewModel.aiSelectedCategory == index
                Button {
                    viewModel.aiSelectedCategory = index
                } label: {
                    Text(categoryLabel(choice))
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(selected ? Color.soukmarPrimary : Color.primary)
                        .background(selected ? Color.soukmarPrimaryLight : Color(.systemBackground))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selected ? Color.soukmarPrimary : Color(.systemGray4), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func resultDetails(_ draft: AiListingDraftDto) -> some View {
        label(i18n.t("ai.attributes"))
        let attrs = attributeEntries(draft)
        if attrs.isEmpty {
            Text(i18n.t("ai.no_attributes")).font(.caption).foregroundStyle(Color.soukmarTextMuted)
        } else {
            ForEach(attrs) { entry in
                fact(i18n.tCatalog("attrs.\(entry.id)", code: entry.id), attrValueLabel(entry.value))
            }
        }

        label(i18n.t("ai.missing"))
        VStack(alignment: .leading, spacing: 2) {
            bullet(i18n.t("ai.missing_default"))
            if (draft.brand ?? "").isEmpty { bullet(i18n.t("ai.missing_brand")) }
            if viewModel.aiSelectedCategory == 0 {
                ForEach(draft.missingAttributes ?? [], id: \.self) { code in
                    bullet(i18n.tCatalog("attrs.\(code)", code: code))
                }
            }
            ForEach(Array((draft.missingInformation ?? []).enumerated()), id: \.offset) { _, text in
                bullet(text)
            }
        }

        if let keywords = draft.keywords, !keywords.isEmpty {
            label(i18n.t("ai.keywords"))
            Text(keywords.joined(separator: " · ")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)
        }
    }

    @ViewBuilder
    private func resultActions(_ draft: AiListingDraftDto) -> some View {
        primaryButton(
            i18n.t("ai.apply"),
            enabled: !viewModel.aiLoading
                && !viewModel.aiTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !viewModel.aiDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
            viewModel.aiApply()
        }
        if viewModel.aiPhotosChanged {
            outlineButton(i18n.t("ai.reanalyse"), enabled: !viewModel.aiLoading && !viewModel.aiImages.isEmpty) {
                viewModel.aiAnalyse(force: false)
            }
        }
        outlineButton(i18n.t("ai.regenerate"), enabled: !viewModel.aiLoading && !viewModel.aiImages.isEmpty) {
            viewModel.aiAnalyse(force: true)
        }
    }

    // MARK: - pieces

    private struct AttrEntry: Identifiable {
        let id: String
        let value: AiAttrValue
    }

    /// Attributes belong to the main suggestion's subcategory; they are hidden if the user picks an alternative.
    private func attributeEntries(_ draft: AiListingDraftDto) -> [AttrEntry] {
        guard viewModel.aiSelectedCategory == 0 else { return [] }
        return (draft.attributes ?? [:]).keys.sorted().compactMap { code in
            guard let value = draft.attributes?[code] else { return nil }
            return AttrEntry(id: code, value: value)
        }
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        if confidence >= 0.75 { return i18n.t("ai.conf_high") }
        if confidence >= 0.5 { return i18n.t("ai.conf_medium") }
        return i18n.t("ai.conf_low")
    }

    private func categoryLabel(_ choice: AiCategorySuggestionDto) -> String {
        var text = i18n.tCatalog("cats.\(choice.category)", code: choice.category)
        if let sub = choice.subcategoryCode, !sub.isEmpty {
            text += " › " + i18n.tCatalog("subcats.\(sub)", code: sub)
        }
        return text
    }

    /// Option codes (SELECT) have a translation, free text (brand, model) is shown as it is.
    private func attrValueLabel(_ value: AiAttrValue) -> String {
        switch value {
        case .bool(let b):
            return b ? i18n.t("common.yes") : i18n.t("common.no")
        case .text(let s):
            let key = "attrs.opts.\(s)"
            let translated = i18n.t(key)
            return translated == key ? s : translated
        }
    }

    private func thumbnail(index: Int, photo: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = photo.previewImage {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.removePhoto(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .padding(3)
            .disabled(viewModel.aiLoading)
            .accessibilityLabel(i18n.t("ai.photo_remove"))
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(enabled ? Color.soukmarPrimary : Color(.systemGray3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func outlineButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.semibold))
    }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(name).font(.footnote).foregroundStyle(Color.soukmarTextMuted).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bullet(_ text: String) -> some View {
        Text("• \(text)").font(.footnote)
    }

    private func notice(_ text: String, warn: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(warn ? Color.soukmarGold : Color.red)
            Text(text).font(.footnote).foregroundStyle(warn ? Color.primary : Color.red)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(warn ? Color.soukmarGoldLight : Color.soukmarPrimaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
