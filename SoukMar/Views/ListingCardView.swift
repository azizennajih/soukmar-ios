import SwiftUI

/// Mirrors soukmar-android's ListingCard — image, category badge, title,
/// price, city + relative time.
struct ListingCardView: View {
    let listing: ListingDto

    private var cat: CategoryConfig? { categoryConfig(listing.category) }

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

                if listing.isPremium {
                    Text("⭐ Premium")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.soukmarGold)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(listing.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let price = listing.price {
                let (amount, currency) = formatPriceParts(price, currency: listing.currency)
                (Text(amount + " ").font(.subheadline.bold()) + Text(currency).font(.caption))
                    .foregroundStyle(Color.soukmarPrimary)
            } else {
                Text("Prix sur demande").font(.subheadline.bold()).foregroundStyle(Color.soukmarPrimary)
            }

            HStack(spacing: 4) {
                Text(listing.city)
                Text("·")
                Text(timeAgo(listing.createdAt))
            }
            .font(.caption)
            .foregroundStyle(Color.soukmarTextMuted)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(cat?.bg ?? Color(hex: 0xF1F5F9))
            .aspectRatio(1.2, contentMode: .fit)
            .overlay(Text(cat?.emoji ?? "📦").font(.largeTitle))
    }
}
