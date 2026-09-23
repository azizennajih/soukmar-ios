import SwiftUI

/// Mirrors soukmar-android's ListingCard — image, category badge, title,
/// price, city + relative time.
struct ListingCardView: View {
    let listing: ListingDto

    @ObservedObject private var i18n = I18nRepository.shared

    private var cat: CategoryConfig? { categoryConfig(listing.category) }
    private var isBoostTop: Bool { isBoostActive(listing.boostTopUntil) }
    private var isBoostSpotlight: Bool { !isBoostTop && isBoostActive(listing.boostSpotlightUntil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if let first = listing.images.first, let url = URL(string: first) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(1.2, contentMode: .fill)
                        default:
                            placeholder
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.2, contentMode: .fit)
                    .clipped()
                } else {
                    placeholder
                }

                if isBoostTop {
                    Label(i18n.t("listing.boost_top_badge"), systemImage: "crown.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.soukmarPrimary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(6)
                } else if isBoostSpotlight {
                    Label(i18n.t("listing.boost_spotlight_badge"), systemImage: "bolt.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.soukmarPrimaryLight)
                        .foregroundStyle(Color.soukmarPrimary)
                        .clipShape(Capsule())
                        .padding(6)
                } else if listing.isPremium {
                    Label(i18n.t("listing.premium_badge"), systemImage: "star.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.soukmarGold)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isBoostTop ? Color.soukmarPrimary : .clear, lineWidth: 2)
            )

            Text(listing.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let price = listing.price {
                let (amount, currency) = formatPriceParts(price, currency: listing.currency, lang: i18n.currentLang)
                (Text(amount + " ").font(.subheadline.bold()) + Text(currency).font(.caption))
                    .foregroundStyle(Color.soukmarPrimary)
            } else {
                Text(i18n.t("listing.negotiate")).font(.subheadline.bold()).foregroundStyle(Color.soukmarPrimary)
            }

            HStack(spacing: 4) {
                Text(listing.city)
                // Only shown for non-Morocco listings — Morocco is the
                // overwhelming majority, so a foreign listing is the one
                // worth calling out while browsing. Mirrors web's foreignFlag.
                if listing.country != "MA" {
                    Text(flagEmoji(listing.country))
                }
                Text("·")
                Text(i18n.timeAgoT(listing.createdAt))
            }
            .font(.caption)
            .foregroundStyle(Color.soukmarTextMuted)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(cat?.bg ?? Color(hex: 0xF1F5F9))
            .aspectRatio(1.2, contentMode: .fit)
            .overlay(
                Group {
                    if let emoji = cat?.emoji {
                        Text(emoji).font(.largeTitle)
                    } else {
                        Image(systemName: "shippingbox").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
            )
    }
}
