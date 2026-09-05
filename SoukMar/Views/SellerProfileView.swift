import SwiftUI

/// A seller id pushed onto the shared NavigationPath — its own Hashable
/// wrapper, same reasoning as ConversationRoute (String is already taken by
/// listing ids on HomeView's stack).
struct SellerRoute: Hashable {
    let sellerId: String
}

/// Mirrors soukmar-android's SellerProfileScreen — avatar, rating stars,
/// response-time badge, active listings grid, received reviews list.
struct SellerProfileView: View {
    let sellerId: String
    var onOpenListing: (String) -> Void

    @StateObject private var viewModel = SellerProfileViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.notFound || viewModel.profile == nil {
                Text(i18n.t("seller.not_found")).foregroundStyle(.secondary)
            } else if let profile = viewModel.profile {
                content(for: profile)
            }
        }
        .navigationTitle("Profil vendeur")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(sellerId: sellerId) }
    }

    @ViewBuilder
    private func content(for profile: SellerProfileDto) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                identityCard(for: profile)

                VStack(alignment: .leading, spacing: 10) {
                    Text("\(i18n.t("seller.listings_title")) (\(profile.activeListingsCount))").font(.headline)
                    if viewModel.listings.isEmpty {
                        Text(i18n.t("seller.no_listings")).font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(viewModel.listings) { listing in
                                Button {
                                    onOpenListing(listing.id)
                                } label: {
                                    ListingCardView(listing: listing)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("\(i18n.t("seller.reviews_title")) (\(viewModel.reviews.count))").font(.headline)
                    if viewModel.reviews.isEmpty {
                        Text(i18n.t("seller.no_reviews_yet")).font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(viewModel.reviews) { review in
                                ReviewRow(review: review)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func identityCard(for profile: SellerProfileDto) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.soukmarPrimary).frame(width: 84, height: 84)
                if let imageUrl = profile.image, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Text(profile.name.prefix(1).uppercased()).foregroundStyle(.white).font(.title.bold())
                        }
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                } else {
                    Text(profile.name.prefix(1).uppercased()).foregroundStyle(.white).font(.title.bold())
                }
            }
            Text(profile.name).font(.headline)
            if let city = profile.city {
                Text("📍 \(city)").font(.subheadline).foregroundStyle(.secondary)
            }
            if let memberSince = Self.memberSince(profile.createdAt) {
                Text("\(i18n.t("seller.member_since")) \(memberSince)").font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if let avgRating = profile.avgRating, avgRating > 0 {
                    StarRow(rating: Int(avgRating.rounded()))
                    Text(String(format: "%.1f (%d)", avgRating, profile.reviewCount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(i18n.t("seller.no_reviews")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            if let label = Self.responseLabel(profile.avgResponseHours, i18n: i18n) {
                Text("⚡ \(label)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private static func memberSince(_ iso: String) -> String? {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso8601.date(from: iso)
        if date == nil {
            iso8601.formatOptions = [.withInternetDateTime]
            date = iso8601.date(from: iso)
        }
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    /// Mirrors the web's seller.responds_minutes/_hours/_days copy thresholds.
    private static func responseLabel(_ hours: Double?, i18n: I18nRepository) -> String? {
        guard let hours else { return nil }
        if hours < 1 { return i18n.t("seller.responds_minutes") }
        if hours < 24 { return i18n.t("seller.responds_hours", ["hours": String(Int(hours.rounded()))]) }
        return i18n.t("seller.responds_days", ["days": String(Int((hours / 24).rounded()))])
    }
}

private struct StarRow: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Text("★").foregroundStyle(star <= rating ? Color.soukmarGold : Color(.separator))
            }
        }
    }
}

private struct ReviewRow: View {
    let review: ReviewWithDetailsDto
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.soukmarPrimary)
                    .frame(width: 32, height: 32)
                    .overlay(Text((review.reviewer?.name ?? "?").prefix(1).uppercased()).font(.caption.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewer?.name ?? "Anonyme").font(.subheadline.weight(.semibold))
                    StarRow(rating: review.rating)
                }
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment).font(.subheadline)
            }
            Group {
                if let title = review.listing?.title {
                    Text("📌 \(title) · \(i18n.timeAgoT(review.createdAt))")
                } else {
                    Text(i18n.timeAgoT(review.createdAt))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack { SellerProfileView(sellerId: "preview", onOpenListing: { _ in }) }
}
