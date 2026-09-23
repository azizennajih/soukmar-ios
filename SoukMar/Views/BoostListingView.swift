import SwiftUI

/// Distinct wrapper type for a listing id pushed as "open the boost screen"
/// — HomeView's stack root already registers a bare String destination for
/// "open listing detail", so a second String meaning needs its own Hashable
/// type (same pattern as ConversationRoute/SellerRoute/LegalRoute).
struct BoostRoute: Hashable {
    let listingId: String
}

private func iconName(for tier: BoostTierId) -> String {
    switch tier {
    case .bump: return "arrow.up"
    case .spotlight: return "bolt.fill"
    case .top: return "crown.fill"
    case .global: return "globe"
    }
}

/// Mirrors soukmar-android's BoostListingScreen — 4-tier visibility-boost
/// picker with a live 10%-multi-tier-discount price total, submitting a
/// PENDING request (see BoostModels.swift) rather than charging anything
/// directly, since no payment processor exists yet.
struct BoostListingView: View {
    let listingId: String

    @StateObject private var viewModel = BoostListingViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let listing = viewModel.listing {
                content(listing: listing)
            } else {
                Text(i18n.t("boost.error_generic")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(i18n.t("boost.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(id: listingId) }
    }

    @ViewBuilder
    private func content(listing: ListingDto) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Listing summary
                HStack(spacing: 12) {
                    if let first = listing.images.first, let url = URL(string: first) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(.secondarySystemBackground))
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(listing.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        if let price = listing.price {
                            let (amount, currency) = formatPriceParts(price, currency: listing.currency, lang: i18n.currentLang)
                            Text("\(amount) \(currency)").font(.caption.bold())
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(i18n.t("boost.title")).font(.title2.bold())
                Text(i18n.t("boost.subtitle")).font(.subheadline).foregroundStyle(.secondary)

                if let pending = viewModel.boostStatus?.pendingRequest, pending.status == "PENDING" {
                    let tierNames = pending.tiers.map { i18n.t("boost.tier_\($0)_name") }.joined(separator: ", ")
                    let (amount, currency) = formatPriceParts(pending.totalPrice, currency: pending.currency, lang: i18n.currentLang)
                    bannerView(
                        systemImage: "hourglass",
                        title: i18n.t("boost.pending_title"),
                        body: i18n.t("boost.pending_body", ["tiers": tierNames, "price": "\(amount) \(currency)"])
                    )
                } else if viewModel.submitted {
                    bannerView(systemImage: "checkmark.circle.fill", title: i18n.t("boost.confirm_title"), body: i18n.t("boost.confirm_body"))
                } else {
                    ForEach(BOOST_TIERS, id: \.id) { tier in
                        TierRow(
                            tier: tier,
                            selected: viewModel.selectedTiers.contains(tier.id),
                            activeUntil: viewModel.activeUntil(for: tier.id),
                            onToggle: { viewModel.toggle(tier.id) }
                        )
                    }

                    summaryCard
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func bannerView(systemImage: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(Color.soukmarPrimary).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold))
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.soukmarPrimaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var summaryCard: some View {
        let quote = quoteBoostPrice(viewModel.selectedTiers)
        return VStack(alignment: .leading, spacing: 6) {
            summaryRow(i18n.t("boost.subtotal"), "\(quote.subtotal) MAD")
            if quote.discountPercent > 0 {
                summaryRow(i18n.t("boost.discount"), "-\(quote.subtotal - quote.total) MAD", color: Color.soukmarPrimary)
            }
            Divider().padding(.vertical, 4)
            summaryRow(i18n.t("boost.total"), "\(quote.total) MAD", bold: true)

            Text(i18n.t("boost.payment_note")).font(.caption).foregroundStyle(.secondary).padding(.top, 6)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(.caption.weight(.semibold)).foregroundStyle(.red).padding(.top, 4)
            }

            Button {
                viewModel.submit(onSelectAtLeastOne: { viewModel.errorMessage = i18n.t("boost.select_at_least_one") })
            } label: {
                Text(viewModel.submitting ? i18n.t("boost.submitting") : i18n.t("boost.submit"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.soukmarPrimary)
            .disabled(viewModel.submitting)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func summaryRow(_ label: String, _ value: String, bold: Bool = false, color: Color = .secondary) -> some View {
        HStack {
            Text(label).font(bold ? .headline : .subheadline).foregroundStyle(bold ? .primary : color)
            Spacer()
            Text(value).font(bold ? .headline : .subheadline.weight(.semibold)).foregroundStyle(bold ? .primary : color)
        }
    }
}

private struct TierRow: View {
    let tier: BoostTier
    let selected: Bool
    let activeUntil: String?
    let onToggle: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Color.soukmarPrimary : Color(.systemGray3))
                    .font(.title3)

                Image(systemName: iconName(for: tier.id))
                    .foregroundStyle(Color.soukmarPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.soukmarPrimaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(i18n.t("boost.tier_\(tier.id.rawValue)_name")).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                        Spacer()
                        Text("\(tier.priceMAD) MAD").font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    }
                    Text(i18n.t("boost.tier_\(tier.id.rawValue)_desc")).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(tier.durationDays == nil ? i18n.t("boost.duration_instant") : i18n.t("boost.duration_days", ["n": String(tier.durationDays!)]))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                        if let activeUntil {
                            Text(i18n.t("boost.active_until", ["date": String(activeUntil.prefix(10))]))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.soukmarPrimaryLight)
                                .foregroundStyle(Color.soukmarPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .background(selected ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground).opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.soukmarPrimary : Color(.separator), lineWidth: selected ? 1.5 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { BoostListingView(listingId: "preview") }
}
