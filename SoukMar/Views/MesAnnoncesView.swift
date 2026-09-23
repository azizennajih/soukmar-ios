import SwiftUI

private struct StatusStyle {
    let label: String
    let bg: Color
    let fg: Color
}

private func statusStyle(_ status: String, _ i18n: I18nRepository) -> StatusStyle {
    switch status {
    case "ACTIVE": return StatusStyle(label: i18n.t("annonces.active"), bg: Color(hex: 0xDCFCE7), fg: Color(hex: 0x15803D))
    case "RESERVED": return StatusStyle(label: i18n.t("annonces.reserved"), bg: Color(hex: 0xFEF9C3), fg: Color(hex: 0xA16207))
    case "PENDING": return StatusStyle(label: i18n.t("annonces.pending"), bg: Color(hex: 0xFEF9C3), fg: Color(hex: 0xA16207))
    case "SOLD": return StatusStyle(label: i18n.t("annonces.sold"), bg: Color(hex: 0xDBEAFE), fg: Color(hex: 0x1D4ED8))
    case "REJECTED": return StatusStyle(label: i18n.t("annonces.rejected"), bg: Color(hex: 0xFEE2E2), fg: Color(hex: 0xB91C1C))
    case "EXPIRED": return StatusStyle(label: i18n.t("annonces.expired"), bg: Color(hex: 0xFEE2E2), fg: Color(hex: 0xB91C1C))
    default: return StatusStyle(label: status, bg: Color(.secondarySystemBackground), fg: .secondary)
    }
}

/// Mirrors soukmar-android's MesAnnoncesScreen — own listings with
/// bump/reserve-toggle/edit/delete actions and a lazy-loaded 14-day view
/// stats panel per listing.
struct MesAnnoncesView: View {
    var onOpenListing: (String) -> Void
    var onEditListing: (String) -> Void
    var onNewListing: () -> Void
    var onBoostListing: (String) -> Void

    @StateObject private var viewModel = MesAnnoncesViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if viewModel.loading {
                    ProgressView()
                } else if viewModel.listings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.listings) { listing in
                                VStack(spacing: 0) {
                                    ListingRow(
                                        listing: listing,
                                        canBump: viewModel.canBump(listing),
                                        bumping: viewModel.bumpingId == listing.id,
                                        statsOpen: viewModel.statsOpenId == listing.id,
                                        onOpen: { onOpenListing(listing.id) },
                                        onEdit: { onEditListing(listing.id) },
                                        onBoost: { onBoostListing(listing.id) },
                                        onToggleReserve: { viewModel.toggleReserve(listing) },
                                        onBump: { viewModel.bump(listing) },
                                        onToggleStats: { viewModel.toggleStats(listing) },
                                        onDelete: { viewModel.requestDelete(listing.id) }
                                    )
                                    if viewModel.statsOpenId == listing.id {
                                        StatsPanel(days: viewModel.statsData[listing.id], funnel: viewModel.funnelData[listing.id])
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }

            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.subheadline)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 16)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        viewModel.clearToast()
                    }
            }
        }
        .navigationTitle("\(i18n.t("mes_annonces.title")) (\(viewModel.listings.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onNewListing()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(i18n.t("mes_annonces.confirm_delete"), isPresented: Binding(
            get: { viewModel.deleteConfirmId != nil },
            set: { if !$0 { viewModel.dismissDelete() } }
        )) {
            Button(i18n.t("mes_annonces.delete"), role: .destructive) { viewModel.confirmDelete() }
            Button(i18n.t("common.cancel"), role: .cancel) { viewModel.dismissDelete() }
        } message: {
            Text("Cette action est irréversible.")
        }
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.clipboard").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(i18n.t("mes_annonces.empty")).font(.title3.bold())
            Text(i18n.t("mes_annonces.empty_sub"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(i18n.t("mes_annonces.post_btn"), action: onNewListing)
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct ListingRow: View {
    let listing: ListingDto
    let canBump: Bool
    let bumping: Bool
    let statsOpen: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onBoost: () -> Void
    let onToggleReserve: () -> Void
    let onBump: () -> Void
    let onToggleStats: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var i18n = I18nRepository.shared

    private var cat: CategoryConfig? { categoryConfig(listing.category) }
    private var style: StatusStyle { statusStyle(listing.status, i18n) }
    private var canToggleReserve: Bool { listing.status == "ACTIVE" || listing.status == "RESERVED" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onOpen) {
                    Group {
                        if let first = listing.images.first, let url = URL(string: first) {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle().fill(cat?.bg ?? Color(.secondarySystemBackground))
                                }
                            }
                        } else {
                            Rectangle().fill(cat?.bg ?? Color(.secondarySystemBackground))
                                .overlay(
                                    Group {
                                        if let emoji = cat?.emoji {
                                            Text(emoji).font(.title2)
                                        } else {
                                            Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary)
                                        }
                                    }
                                )
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(listing.title).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                            Spacer()
                            Text(style.label)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(style.bg)
                                .foregroundStyle(style.fg)
                                .clipShape(Capsule())
                        }
                        if let price = listing.price {
                            let (amount, currency) = formatPriceParts(price, currency: listing.currency, lang: i18n.currentLang)
                            Text("\(amount) \(currency)").font(.caption.bold()).foregroundStyle(.primary)
                        } else {
                            Text(i18n.t("listing.negotiate")).font(.caption.bold()).foregroundStyle(.primary)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "eye").font(.system(size: 10))
                            Text("\(listing.views) \(i18n.t("listing.views")) ·")
                            Image(systemName: "clock").font(.system(size: 10))
                            Text("\(i18n.timeAgoT(listing.createdAt)) ·")
                            Image(systemName: "mappin").font(.system(size: 10))
                            Text(listing.city)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.soukmarTextMuted)
                        .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                RowActionButton(systemName: "eye", action: onOpen)
                if canToggleReserve {
                    RowActionButton(
                        systemName: listing.status == "RESERVED" ? "lock.open" : "lock",
                        active: listing.status == "RESERVED",
                        action: onToggleReserve
                    )
                }
                RowActionButton(systemName: "pencil", action: onEdit)
                if canToggleReserve {
                    RowActionButton(systemName: "arrow.up", enabled: canBump && !bumping, action: onBump)
                    RowActionButton(systemName: "bolt.fill", action: onBoost)
                }
                RowActionButton(systemName: "chart.bar", active: statsOpen, action: onToggleStats)
                RowActionButton(systemName: "trash", danger: true, action: onDelete)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct RowActionButton: View {
    let systemName: String
    var enabled: Bool = true
    var active: Bool = false
    var danger: Bool = false
    let action: () -> Void

    private var tint: Color {
        if !enabled { return Color.soukmarTextMuted.opacity(0.4) }
        if danger { return .red }
        if active { return Color.soukmarPrimary }
        return Color.soukmarTextMuted
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 36, height: 36)
                .foregroundStyle(tint)
        }
        .disabled(!enabled)
    }
}

private struct StatsPanel: View {
    let days: [ViewStatDayDto]?
    let funnel: FunnelDto?
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t("mes_annonces.stats_title")).font(.caption.weight(.semibold))
            if let days {
                let maxCount = max(days.map(\.count).max() ?? 0, 1)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(days, id: \.date) { day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.soukmarPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(48 * CGFloat(day.count) / CGFloat(maxCount), 3))
                    }
                }
                .frame(height: 48)
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 48)
            }

            Divider().padding(.vertical, 2)

            Text(i18n.t("mes_annonces.funnel_title")).font(.caption.weight(.semibold))
            if let funnel {
                VStack(spacing: 6) {
                    FunnelRow(label: i18n.t("mes_annonces.funnel_views"), count: funnel.views, pct: 100, accented: false)
                    FunnelRow(label: i18n.t("mes_annonces.funnel_favorites"), count: funnel.favorites, pct: Self.pct(funnel.favorites, of: funnel.views), accented: false)
                    FunnelRow(label: i18n.t("mes_annonces.funnel_contacts"), count: funnel.contacts, pct: Self.pct(funnel.contacts, of: funnel.views), accented: false)
                    FunnelRow(label: i18n.t("mes_annonces.funnel_offers"), count: funnel.offers, pct: Self.pct(funnel.offers, of: funnel.views), accented: false)
                    FunnelRow(label: i18n.t("mes_annonces.funnel_accepted"), count: funnel.offersAccepted, pct: Self.pct(funnel.offersAccepted, of: funnel.views), accented: true)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 32)
            }
        }
        .padding(12)
        .background(Color.soukmarPrimaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 6)
    }

    /// Each funnel step's bar width relative to the top of the funnel
    /// (views) — mirrors Web's funnelPct(): 100 for views itself, shrinking
    /// down through favorites/contacts/offers/accepted. Guards against
    /// divide-by-zero on a brand-new listing.
    private static func pct(_ count: Int, of views: Int) -> Double {
        guard views > 0 else { return 0 }
        return min(100, Double(count) / Double(views) * 100)
    }
}

private struct FunnelRow: View {
    let label: String
    let count: Int
    let pct: Double
    let accented: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 8)
                    Capsule()
                        .fill(accented ? Color.green : Color.soukmarPrimary)
                        .frame(width: geo.size.width * CGFloat(pct / 100), height: 8)
                }
            }
            .frame(height: 8)
            Text("\(count)")
                .font(.caption2.bold())
                .frame(width: 28, alignment: .trailing)
        }
    }
}

#Preview {
    NavigationStack { MesAnnoncesView(onOpenListing: { _ in }, onEditListing: { _ in }, onNewListing: {}, onBoostListing: { _ in }) }
}
