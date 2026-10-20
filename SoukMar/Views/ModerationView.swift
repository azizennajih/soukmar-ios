import SwiftUI

private let QUEUE_STATUSES = ["PENDING", "CHANGES_REQUESTED", "REJECTED", "SUSPENDED", "ACTIVE", "ALL"]

private func moderationStatusLabel(_ status: String, _ i18n: I18nRepository) -> String {
    switch status {
    case "ACTIVE": return i18n.t("annonces.active")
    case "RESERVED": return i18n.t("annonces.reserved")
    case "PENDING": return i18n.t("annonces.pending")
    case "SOLD": return i18n.t("annonces.sold")
    case "REJECTED": return i18n.t("annonces.rejected")
    case "EXPIRED": return i18n.t("annonces.expired")
    case "CHANGES_REQUESTED": return i18n.t("annonces.changes_requested")
    case "SUSPENDED": return i18n.t("annonces.suspended")
    case "ALL": return i18n.t("moderation.f_all_status")
    default: return status
    }
}

private func moderationStatusColors(_ status: String) -> (bg: Color, fg: Color) {
    switch status {
    case "ACTIVE": return (Color(hex: 0xDCFCE7), Color(hex: 0x15803D))
    case "SOLD": return (Color(hex: 0xDBEAFE), Color(hex: 0x1D4ED8))
    case "REJECTED", "SUSPENDED", "EXPIRED": return (Color(hex: 0xFEE2E2), Color(hex: 0xB91C1C))
    default: return (Color(hex: 0xFEF9C3), Color(hex: 0xA16207))
    }
}

private func countryLabel(_ code: String, _ lang: String) -> String {
    Locale(identifier: lang).localizedString(forRegionCode: code) ?? code
}

private func highestSeverity(_ signals: [ModerationSignalDto]) -> String? {
    if signals.contains(where: { $0.level == "high" }) { return "high" }
    if signals.contains(where: { $0.level == "medium" }) { return "medium" }
    return signals.isEmpty ? nil : "low"
}

private struct ModerationStatusBadge: View {
    let status: String
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        let colors = moderationStatusColors(status)
        Text(moderationStatusLabel(status, i18n))
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(colors.bg)
            .foregroundStyle(colors.fg)
            .clipShape(Capsule())
    }
}

/// Mirrors soukmar-android's ModerationPanel — the "Anzeigenmoderation" tab of the admin area: queue with filters,
/// detail with the automatic warnings, seller data and history, and the decisions.
struct ModerationView: View {
    var onOpenListing: (String) -> Void

    @StateObject private var viewModel = ModerationViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            if let detail = viewModel.detail {
                ModerationDetailView(viewModel: viewModel, detail: detail, onOpenListing: onOpenListing)
            } else if viewModel.detailLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ModerationQueueView(viewModel: viewModel)
            }

            if let key = viewModel.messageKey {
                VStack(spacing: 6) {
                    Text(i18n.t(key))
                    if let extra = viewModel.extraMessageKey { Text(i18n.t(extra)) }
                }
                .font(.subheadline)
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 16)
                .task(id: key) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    viewModel.clearMessage()
                }
            }
        }
        .task { viewModel.start() }
        .alert(confirmTitle, isPresented: Binding(
            get: { viewModel.confirmAction != nil },
            set: { if !$0 { viewModel.cancelDecision() } }
        )) {
            Button(viewModel.confirmAction == "approve" ? i18n.t("moderation.act_approve") : i18n.t("moderation.act_requeue")) { viewModel.confirm() }
            Button(i18n.t("common.cancel"), role: .cancel) { viewModel.cancelDecision() }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.reasonAction != nil },
            set: { if !$0 { viewModel.cancelDecision() } }
        )) {
            ReasonSheet(viewModel: viewModel)
        }
    }

    private var confirmTitle: String {
        if viewModel.confirmAction == "approve" {
            return i18n.t("moderation.confirm_approve", ["title": viewModel.detail?.listing.title ?? ""])
        }
        return i18n.t("moderation.confirm_requeue")
    }
}

// MARK: - queue

private struct ModerationQueueView: View {
    @ObservedObject var viewModel: ModerationViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(i18n.t("moderation.subtitle")).font(.caption).foregroundStyle(Color.soukmarTextMuted)

                if let s = viewModel.summary {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SummaryCard(value: s.pending ?? 0, label: i18n.t("moderation.sum_pending"), highlight: (s.pending ?? 0) > 0) { viewModel.selectStatus("PENDING") }
                            SummaryCard(value: s.highRiskPending ?? 0, label: i18n.t("moderation.sum_high"), danger: (s.highRiskPending ?? 0) > 0, onTap: nil)
                            SummaryCard(value: s.changesRequested ?? 0, label: i18n.t("moderation.sum_changes")) { viewModel.selectStatus("CHANGES_REQUESTED") }
                            SummaryCard(value: s.suspended ?? 0, label: i18n.t("moderation.sum_suspended")) { viewModel.selectStatus("SUSPENDED") }
                            SummaryCard(value: s.decidedToday ?? 0, label: i18n.t("moderation.sum_today"), onTap: nil)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(QUEUE_STATUSES, id: \.self) { st in
                            Button {
                                viewModel.selectStatus(st)
                            } label: {
                                Text(moderationStatusLabel(st, i18n))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(viewModel.status == st ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                                    .foregroundStyle(viewModel.status == st ? Color.soukmarPrimary : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Menu {
                            Button(i18n.t("moderation.f_all_countries")) { viewModel.selectCountry("") }
                            ForEach(COUNTRIES, id: \.code) { c in
                                Button("\(flagEmoji(c.code)) \(countryLabel(c.code, i18n.currentLang))") { viewModel.selectCountry(c.code) }
                            }
                        } label: {
                            FilterMenuLabel(text: viewModel.country.isEmpty ? i18n.t("moderation.f_all_countries") : "\(flagEmoji(viewModel.country)) \(countryLabel(viewModel.country, i18n.currentLang))")
                        }
                        Menu {
                            Button(i18n.t("moderation.f_all_categories")) { viewModel.selectCategory("") }
                            ForEach(CATEGORIES, id: \.value) { c in
                                Button(i18n.tCatalog("cats.\(c.value)", code: c.value)) { viewModel.selectCategory(c.value) }
                            }
                        } label: {
                            FilterMenuLabel(text: viewModel.category.isEmpty ? i18n.t("moderation.f_all_categories") : i18n.tCatalog("cats.\(viewModel.category)", code: viewModel.category))
                        }
                        Menu {
                            Button(i18n.t("moderation.sort_oldest")) { viewModel.selectSort("oldest") }
                            Button(i18n.t("moderation.sort_risk")) { viewModel.selectSort("risk") }
                            Button(i18n.t("moderation.sort_newest")) { viewModel.selectSort("newest") }
                        } label: {
                            FilterMenuLabel(text: sortLabel)
                        }
                    }
                }

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.soukmarTextMuted)
                    TextField(i18n.t("moderation.f_search_ph"), text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { viewModel.search() }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack {
                    Text(i18n.t("moderation.count", ["n": String(viewModel.total)])).font(.caption).foregroundStyle(Color.soukmarTextMuted)
                    Spacer()
                    Button(i18n.t("moderation.f_reset")) { viewModel.resetFilters() }.font(.caption)
                }

                if viewModel.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(24)
                } else if viewModel.loadError {
                    Text(i18n.t("auth.generic_error")).foregroundStyle(.red)
                } else if viewModel.items.isEmpty {
                    Text(i18n.t("moderation.empty")).foregroundStyle(Color.soukmarTextMuted).padding(24)
                } else {
                    ForEach(viewModel.items) { item in
                        QueueRow(item: item) { viewModel.openDetail(item.id) }
                    }
                    if viewModel.page < viewModel.pages {
                        Button {
                            viewModel.loadMore()
                        } label: {
                            Text(viewModel.loadingMore ? i18n.t("admin.loading") : i18n.t("moderation.next")).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.loadingMore)
                    }
                }
            }
            .padding(12)
        }
    }

    private var sortLabel: String {
        switch viewModel.sort {
        case "risk": return i18n.t("moderation.sort_risk")
        case "newest": return i18n.t("moderation.sort_newest")
        default: return i18n.t("moderation.sort_oldest")
        }
    }
}

private struct FilterMenuLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(Capsule().stroke(Color(.separator), lineWidth: 1))
            .foregroundStyle(.primary)
    }
}

private struct SummaryCard: View {
    let value: Int
    let label: String
    var highlight = false
    var danger = false
    var onTap: (() -> Void)?

    init(value: Int, label: String, highlight: Bool = false, danger: Bool = false, onTap: (() -> Void)?) {
        self.value = value
        self.label = label
        self.highlight = highlight
        self.danger = danger
        self.onTap = onTap
    }

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.title2.bold())
            Text(label).font(.caption2).foregroundStyle(Color.soukmarTextMuted).lineLimit(2)
        }
        .frame(width: 110, alignment: .leading)
        .padding(12)
        .background(danger ? Color.soukmarPrimaryLight : (highlight ? Color.soukmarGoldLight : Color(.secondarySystemBackground).opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(danger ? Color.soukmarPrimary : (highlight ? Color.soukmarGold : Color(.separator)), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))

        if let onTap {
            Button(action: onTap) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }
}

private struct QueueRow: View {
    let item: ModerationQueueItemDto
    let onOpen: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    private var priceText: String {
        if item.priceType == "FREE" { return i18n.t("listing.free_badge") }
        guard let price = item.price else { return i18n.t("listing.negotiate") }
        let (amount, currency) = formatPriceParts(price, currency: item.currency ?? "MAD", lang: i18n.currentLang)
        return "\(amount) \(currency)"
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if let first = item.images?.first, let url = URL(string: first) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(.secondarySystemBackground))
                            }
                        }
                    } else {
                        Rectangle().fill(Color(.secondarySystemBackground))
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                        Spacer()
                        ModerationStatusBadge(status: item.status)
                    }
                    Text("\(flagEmoji(item.country ?? "MA")) \(cityLabel(item.city ?? "", lang: i18n.currentLang)) · \(i18n.tCatalog("cats.\(item.category)", code: item.category)) · \(priceText)")
                        .font(.caption2).foregroundStyle(Color.soukmarTextMuted).lineLimit(1)
                    Text("\(item.user?.name ?? "") · \(i18n.t("moderation.submitted", ["time": i18n.timeAgoT(item.submittedAt ?? item.createdAt)]))")
                        .font(.caption2).foregroundStyle(Color.soukmarTextMuted).lineLimit(1)
                    if let reason = item.moderationReason, !reason.isEmpty, item.status != "PENDING" {
                        Text(reason).font(.caption2).foregroundStyle(Color.soukmarTextMuted).lineLimit(1)
                    }
                    if let sev = highestSeverity(item.signals) {
                        Text("⚠ " + i18n.t("moderation.warnings", ["n": String(item.signals.count)]))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(sev == "high" ? Color.soukmarPrimary : (sev == "medium" ? Color.soukmarGold : Color.soukmarTextMuted))
                    } else {
                        Text(i18n.t("moderation.no_warnings")).font(.caption2).foregroundStyle(Color.soukmarTextMuted)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - detail

private struct ModerationDetailView: View {
    @ObservedObject var viewModel: ModerationViewModel
    let detail: ModerationDetailDto
    let onOpenListing: (String) -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    private var l: ModerationListingDto { detail.listing }
    private var allowed: [String] { detail.allowedActions ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.closeDetail()
                    } label: {
                        Label(i18n.t("moderation.back"), systemImage: "chevron.backward").font(.subheadline)
                    }
                    Spacer()
                    ModerationStatusBadge(status: l.status)
                }
                Text("ID \(l.id)").font(.caption2).foregroundStyle(Color.soukmarTextMuted).lineLimit(1)

                // Decision first: the reviewer should not have to scroll for the buttons.
                card { decisionBlock }
                card { listingBlock }
                card { signalsBlock }
                card { sellerBlock }
                card { historyBlock }
            }
            .padding(12)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var decisionBlock: some View {
        Text(i18n.t("moderation.act_title")).font(.subheadline.bold())
        if allowed.isEmpty {
            Text(i18n.t("moderation.act_none")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)
        }
        if let reason = l.moderationReason, !reason.isEmpty, l.status != "ACTIVE" {
            Text("\(i18n.t("moderation.last_reason")) \(reason)").font(.caption).foregroundStyle(Color.soukmarTextMuted)
        }
        if allowed.contains("approve") {
            Button {
                viewModel.askConfirm("approve")
            } label: {
                Label(i18n.t("moderation.act_approve"), systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.soukmarPrimary)
            .disabled(viewModel.submitting)
        }
        if allowed.contains("request_changes") {
            Button {
                viewModel.startReason("request-changes")
            } label: {
                Label(i18n.t("moderation.act_request"), systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.submitting)
        }
        if allowed.contains("reject") {
            Button(role: .destructive) {
                viewModel.startReason("reject")
            } label: {
                Label(i18n.t("moderation.act_reject"), systemImage: "xmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.submitting)
        }
        if allowed.contains("suspend") {
            Button(role: .destructive) {
                viewModel.startReason("suspend")
            } label: {
                Label(i18n.t("moderation.act_suspend"), systemImage: "pause").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.submitting)
        }
        if allowed.contains("requeue") {
            Button {
                viewModel.askConfirm("requeue")
            } label: {
                Label(i18n.t("moderation.act_requeue"), systemImage: "clock").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.soukmarPrimary)
            .disabled(viewModel.submitting)
        }
    }

    @ViewBuilder
    private var listingBlock: some View {
        let images = l.images ?? []
        if images.isEmpty {
            Text(i18n.t("moderation.d_no_images")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, urlString in
                        AsyncImage(url: URL(string: urlString)) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(.secondarySystemBackground))
                            }
                        }
                        .frame(width: 220, height: 165)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        Text(l.title).font(.title3.bold())
        Text(priceText).font(.headline)
        Text("\(i18n.tCatalog("cats.\(l.category)", code: l.category)) · \(flagEmoji(l.country ?? "MA")) \(cityLabel(l.city ?? "", lang: i18n.currentLang)), \(countryLabel(l.country ?? "MA", i18n.currentLang))")
            .font(.caption).foregroundStyle(Color.soukmarTextMuted)
        Text(l.description ?? "").font(.subheadline)
        if (l.phone ?? "").isEmpty == false || (l.whatsapp ?? "").isEmpty == false {
            Text(i18n.t("moderation.d_contact")).font(.caption.weight(.semibold)).foregroundStyle(Color.soukmarTextMuted)
            if let phone = l.phone, !phone.isEmpty { Text("\(i18n.t("moderation.s_phone")): \(phone)").font(.footnote) }
            if let wa = l.whatsapp, !wa.isEmpty { Text("WhatsApp: \(wa)").font(.footnote) }
        }
        Button {
            onOpenListing(l.id)
        } label: {
            Label(i18n.t("moderation.d_preview"), systemImage: "eye")
        }
        .buttonStyle(.bordered)
    }

    private var priceText: String {
        if l.priceType == "FREE" { return i18n.t("listing.free_badge") }
        guard let price = l.price else { return i18n.t("listing.negotiate") }
        let (amount, currency) = formatPriceParts(price, currency: l.currency ?? "MAD", lang: i18n.currentLang)
        return "\(amount) \(currency)"
    }

    @ViewBuilder
    private var signalsBlock: some View {
        Text(i18n.t("moderation.sig_title")).font(.subheadline.bold())
        if l.signals.isEmpty {
            Text(i18n.t("moderation.sig_none")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)
        } else {
            ForEach(Array(l.signals.enumerated()), id: \.offset) { _, sig in
                SignalRow(severity: sig.level, text: signalText(sig.code, sig.message, sig.paramStrings), detail: (sig.code == "KEYWORD" || sig.code == "AI_FLAGGED") ? sig.message : nil, onTap: nil)
            }
        }
        Text(i18n.t("moderation.sig_disclaimer")).font(.caption2).foregroundStyle(Color.soukmarTextMuted)

        let duplicates = detail.duplicates ?? []
        if !duplicates.isEmpty {
            Text(i18n.t("moderation.dup_title")).font(.subheadline.bold()).padding(.top, 6)
            ForEach(Array(duplicates.enumerated()), id: \.offset) { _, dup in
                SignalRow(
                    severity: dup.level,
                    text: signalText(dup.code, dup.message, dup.paramStrings),
                    detail: dup.listing.map { "\($0.title ?? "") (\(moderationStatusLabel($0.status ?? "", i18n)))" },
                    onTap: dup.listing.map { other in { viewModel.openDetail(other.id) } }
                )
            }
        }
    }

    private func signalText(_ code: String, _ fallback: String?, _ params: [String: String]) -> String {
        let key = "moderation.sig_\(code)"
        let text = i18n.t(key, params)
        return text == key ? (fallback ?? code) : text
    }

    @ViewBuilder
    private var sellerBlock: some View {
        let s = detail.seller ?? ModerationSellerDto()
        Text(i18n.t("moderation.s_title")).font(.subheadline.bold())
        InfoRow(label: i18n.t("moderation.s_name"), value: s.name ?? "")
        InfoRow(label: i18n.t("moderation.s_email"), value: s.email ?? "")
        if let phone = s.phone, !phone.isEmpty { InfoRow(label: i18n.t("moderation.s_phone"), value: phone) }
        if let since = s.createdAt { InfoRow(label: i18n.t("moderation.s_since"), value: i18n.timeAgoT(since)) }
        InfoRow(label: i18n.t("moderation.s_email_ok"), value: i18n.t((s.emailVerified ?? false) ? "common.yes" : "common.no"))
        InfoRow(label: i18n.t("moderation.s_phone_ok"), value: i18n.t((s.phoneVerified ?? false) ? "common.yes" : "common.no"))
        InfoRow(label: i18n.t("moderation.s_id_ok"), value: i18n.t((s.idVerified ?? false) ? "common.yes" : "common.no"))
        InfoRow(label: i18n.t("moderation.s_total"), value: String(s.listingsTotal ?? 0))
        InfoRow(label: i18n.t("moderation.s_public"), value: String(s.listingsPublic ?? 0))
        InfoRow(label: i18n.t("moderation.s_rejected"), value: String(s.listingsRejected ?? 0), warn: (s.listingsRejected ?? 0) > 0)
        InfoRow(label: i18n.t("moderation.s_reports"), value: String(s.reportsAgainst ?? 0), warn: (s.reportsAgainst ?? 0) > 0)
    }

    @ViewBuilder
    private var historyBlock: some View {
        let events = detail.events ?? []
        Text(i18n.t("moderation.hist_title")).font(.subheadline.bold())
        if events.isEmpty {
            Text(i18n.t("moderation.hist_empty")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)
        }
        ForEach(events) { ev in
            EventRow(event: ev, resending: viewModel.resendingEventId == ev.id) { viewModel.resendMail(ev.id) }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var warn = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).foregroundStyle(Color.soukmarTextMuted)
            Spacer(minLength: 12)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(warn ? Color.red : Color.primary).multilineTextAlignment(.trailing)
        }
    }
}

private struct SignalRow: View {
    let severity: String
    let text: String
    let detail: String?
    let onTap: (() -> Void)?
    @ObservedObject private var i18n = I18nRepository.shared

    private var tint: Color {
        switch severity {
        case "high": return Color.soukmarPrimary
        case "medium": return Color.soukmarGold
        default: return Color.soukmarTextMuted
        }
    }

    var body: some View {
        let row = HStack(alignment: .top, spacing: 8) {
            Text(i18n.t("moderation.sev_\(severity)").uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.caption).foregroundStyle(.primary)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.caption2).foregroundStyle(onTap != nil ? Color.soukmarPrimary : Color.soukmarTextMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(severity == "high" ? Color.soukmarPrimaryLight : (severity == "medium" ? Color.soukmarGoldLight : Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(severity == "low" ? Color(.separator) : tint, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))

        if let onTap {
            Button(action: onTap) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

private struct EventRow: View {
    let event: ModerationEventDto
    let resending: Bool
    let onResend: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    private var who: String {
        let role = i18n.t("moderation.actor_\(event.actorRole ?? "SYSTEM")")
        if let name = event.actorName, !name.isEmpty, event.actorRole == "ADMIN" || event.actorRole == "MODERATOR" {
            return "\(name) (\(role))"
        }
        return role
    }

    private var title: String {
        guard let from = event.fromStatus else { return i18n.t("moderation.ev_submitted") }
        return i18n.t("moderation.ev_changed", ["from": moderationStatusLabel(from, i18n), "to": moderationStatusLabel(event.toStatus, i18n)])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.footnote.weight(.semibold))
            Text("\(who) · \(i18n.timeAgoT(event.createdAt))").font(.caption2).foregroundStyle(Color.soukmarTextMuted)
            if let reason = event.reason, !reason.isEmpty { Text(reason).font(.caption) }
            if let kind = event.emailKind, !kind.isEmpty {
                let st = event.emailStatus ?? "PENDING"
                HStack(spacing: 6) {
                    Text("✉ " + i18n.t("moderation.mail_\(st)"))
                        .font(.caption2)
                        .foregroundStyle(st == "FAILED" ? Color.red : Color.soukmarTextMuted)
                    if st == "FAILED" || st == "PENDING" {
                        Button(i18n.t("moderation.mail_resend"), action: onResend).font(.caption2).disabled(resending)
                    }
                }
                if let err = event.emailError, !err.isEmpty { Text(err).font(.system(size: 10)).foregroundStyle(Color.red) }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - reason sheet

private struct ReasonSheet: View {
    @ObservedObject var viewModel: ModerationViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    private var title: String {
        switch viewModel.reasonAction {
        case "reject": return i18n.t("moderation.act_reject")
        case "suspend": return i18n.t("moderation.act_suspend")
        default: return i18n.t("moderation.act_request")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(i18n.t("moderation.reason_label")).font(.footnote).foregroundStyle(Color.soukmarTextMuted)
                TextField(i18n.t("moderation.reason_ph"), text: $viewModel.reason, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
                    .onChange(of: viewModel.reason) { newValue in
                        if newValue.count > MODERATION_REASON_MAX { viewModel.reason = String(newValue.prefix(MODERATION_REASON_MAX)) }
                    }
                Text("\(viewModel.reason.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(MODERATION_REASON_MAX) · \(i18n.t("moderation.reason_min", ["n": String(MODERATION_REASON_MIN)]))")
                    .font(.caption2)
                    .foregroundStyle(!viewModel.reason.isEmpty && !viewModel.reasonValid ? Color.red : Color.soukmarTextMuted)
                if viewModel.reasonAction == "reject" {
                    Toggle(i18n.t("moderation.allow_resubmit"), isOn: $viewModel.allowResubmit).font(.footnote)
                }
                Button {
                    viewModel.submitReason()
                } label: {
                    if viewModel.submitting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text(i18n.t("moderation.send_decision")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .disabled(!viewModel.reasonValid || viewModel.submitting)
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(i18n.t("common.cancel")) { viewModel.cancelDecision() }
                }
            }
        }
    }
}
