import SwiftUI

/// True for a listing created within the last 24 hours (mirrors Android's isNewListing / the web's "new" badge).
func isNewListing(_ createdAt: String) -> Bool {
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    guard let date = withFraction.date(from: createdAt) ?? plain.date(from: createdAt) else { return false }
    return Date().timeIntervalSince(date) < 24 * 3600
}

/// The listing card of the whole app (home, search results, favourites, seller profile, similar listings).
/// Square photo, price first, then title, place and time, seller. Yellow marks paid visibility (Top, Spotlight, Premium);
/// the heart sits on the photo and has a 44-pt touch target. `showFavorite` is off where the screen has its own
/// favourite control.
struct ListingCardView: View {
    let listing: ListingDto
    var showFavorite: Bool = true

    @ObservedObject private var i18n = I18nRepository.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    private var isBoostTop: Bool { isBoostActive(listing.boostTopUntil) }
    private var isBoostSpotlight: Bool { !isBoostTop && isBoostActive(listing.boostSpotlightUntil) }
    private var isFavorite: Bool { favorites.ids.contains(listing.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
            details
        }
        .background(isBoostSpotlight ? Color.soukmarGoldLight : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(isBoostTop ? Color.soukmarAccent : Color.soukmarBorder, lineWidth: isBoostTop ? 1.5 : 1)
        )
    }

    // A square area that always has the same size, whatever the photo's own proportions are.
    private var photo: some View {
        Color.soukmarSurfaceMuted
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let first = listing.images.first, let url = URL(string: first) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if isBoostTop {
                        SoukBadge(text: i18n.t("listing.boost_top_badge"), systemImage: "crown.fill", background: Color.soukmarAccent)
                    } else if isBoostSpotlight {
                        SoukBadge(text: i18n.t("listing.boost_spotlight_badge"), systemImage: "bolt.fill", background: Color.soukmarAccent)
                    } else if listing.isFeatured {
                        SoukBadge(text: i18n.t("listing.premium_badge"), systemImage: "star.fill", background: Color.soukmarAccent)
                    } else if listing.isPremium {
                        SoukBadge(text: i18n.t("listing.pro_badge"), background: Color.soukmarAccent)
                    }
                    if listing.status != "RESERVED" && isNewListing(listing.createdAt) {
                        SoukBadge(text: i18n.t("listing.new_badge"), background: Color.white, foreground: Color.soukmarPrimary)
                    }
                }
                .padding(Spacing.sm)
            }
            .overlay(alignment: .topTrailing) {
                if showFavorite {
                    // A gesture with priority instead of a Button: the card itself is usually the label of a Button,
                    // and the heart must win the tap.
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.soukmarPrimary : Color.soukmarInk)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .highPriorityGesture(TapGesture().onEnded { favorites.toggle(listing.id) })
                        .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(i18n.t(isFavorite ? "listing.fav_remove" : "listing.fav_add"))
                }
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let price = listing.price {
                let parts = formatPriceParts(price, currency: listing.currency, lang: i18n.currentLang)
                (Text(parts.0 + " ").font(.system(size: 17, weight: .heavy)) + Text(parts.1).font(.system(size: 12, weight: .semibold)))
                    .foregroundStyle(Color.soukmarInk)
                    .lineLimit(1)
            } else {
                Text(i18n.t("listing.negotiate"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.soukmarGold)
                    .lineLimit(1)
            }

            Text(listing.title)
                .font(.subheadline)
                .foregroundStyle(Color.soukmarInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            HStack(spacing: 3) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 11))
                Text(cityLabel(listing.city, lang: i18n.currentLang)).lineLimit(1)
                // Only shown for non-Morocco listings — Morocco is the
                // overwhelming majority, so a foreign listing is the one
                // worth calling out while browsing. Mirrors web's foreignFlag.
                if listing.country != "MA" {
                    Text(flagEmoji(listing.country))
                }
                Spacer(minLength: 4)
                Text(i18n.timeAgoT(listing.createdAt))
                    .foregroundStyle(Color.soukmarTextSubtle)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .font(.caption)
            .foregroundStyle(Color.soukmarTextMuted)
            .padding(.top, Spacing.xs)

            if let seller = listing.user {
                HStack(spacing: 3) {
                    Image(systemName: seller.accountType == "BUSINESS" ? "building.2" : "person").font(.system(size: 11))
                    Text(seller.name).lineLimit(1)
                    if seller.emailVerified || seller.phoneVerified || seller.idVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.soukmarSuccess)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.soukmarTextMuted)
                .padding(.top, 2)
            }
        }
        .padding(Spacing.md)
    }

    private var placeholder: some View {
        CategoryIcon(category: listing.category, tint: Color.soukmarTextSubtle)
            .frame(width: 40, height: 40)
    }
}
