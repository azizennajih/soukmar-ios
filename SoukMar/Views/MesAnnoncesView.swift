import SwiftUI

private struct StatusStyle {
    let label: String
    let bg: Color
    let fg: Color
}

private func statusStyle(_ status: String) -> StatusStyle {
    switch status {
    case "ACTIVE": return StatusStyle(label: "Active", bg: Color(hex: 0xDCFCE7), fg: Color(hex: 0x15803D))
    case "RESERVED": return StatusStyle(label: "Réservée", bg: Color(hex: 0xFEF9C3), fg: Color(hex: 0xA16207))
    case "PENDING": return StatusStyle(label: "En attente", bg: Color(hex: 0xFEF9C3), fg: Color(hex: 0xA16207))
    case "SOLD": return StatusStyle(label: "Vendue", bg: Color(hex: 0xDBEAFE), fg: Color(hex: 0x1D4ED8))
    case "REJECTED": return StatusStyle(label: "Rejetée", bg: Color(hex: 0xFEE2E2), fg: Color(hex: 0xB91C1C))
    case "EXPIRED": return StatusStyle(label: "Expirée", bg: Color(hex: 0xFEE2E2), fg: Color(hex: 0xB91C1C))
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

    @StateObject private var viewModel = MesAnnoncesViewModel()

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
                                        onToggleReserve: { viewModel.toggleReserve(listing) },
                                        onBump: { viewModel.bump(listing) },
                                        onToggleStats: { viewModel.toggleStats(listing) },
                                        onDelete: { viewModel.requestDelete(listing.id) }
                                    )
                                    if viewModel.statsOpenId == listing.id {
                                        StatsPanel(days: viewModel.statsData[listing.id])
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
        .navigationTitle("Mes annonces (\(viewModel.listings.count))")
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
        .alert("Supprimer cette annonce ?", isPresented: Binding(
            get: { viewModel.deleteConfirmId != nil },
            set: { if !$0 { viewModel.dismissDelete() } }
        )) {
            Button("Supprimer", role: .destructive) { viewModel.confirmDelete() }
            Button("Annuler", role: .cancel) { viewModel.dismissDelete() }
        } message: {
            Text("Cette action est irréversible.")
        }
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("📋").font(.system(size: 40))
            Text("Aucune annonce").font(.title3.bold())
            Text("Vos annonces publiées apparaîtront ici.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Déposer une annonce", action: onNewListing)
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
    let onToggleReserve: () -> Void
    let onBump: () -> Void
    let onToggleStats: () -> Void
    let onDelete: () -> Void

    private var cat: CategoryConfig? { categoryConfig(listing.category) }
    private var style: StatusStyle { statusStyle(listing.status) }
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
                                .overlay(Text(cat?.emoji ?? "📦").font(.title2))
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
                            let (amount, currency) = formatPriceParts(price, currency: listing.currency)
                            Text("\(amount) \(currency)").font(.caption.bold()).foregroundStyle(.primary)
                        } else {
                            Text("Prix à négocier").font(.caption.bold()).foregroundStyle(.primary)
                        }
                        Text("👁 \(listing.views) vues · 🕐 \(timeAgo(listing.createdAt)) · 📍 \(listing.city)")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vues (14 derniers jours)").font(.caption.weight(.semibold))
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
        }
        .padding(12)
        .background(Color.soukmarPrimaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 6)
    }
}

#Preview {
    NavigationStack { MesAnnoncesView(onOpenListing: { _ in }, onEditListing: { _ in }, onNewListing: {}) }
}
