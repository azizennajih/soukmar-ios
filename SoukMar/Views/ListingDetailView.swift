import SwiftUI

/// Mirrors soukmar-android's ListingDetailScreen — gallery, price with
/// average-price comparison, attributes, favorites, reporting, contacting
/// the seller (phone/WhatsApp/chat), and a link to the seller's public
/// profile.
struct ListingDetailView: View {
    let listingId: String
    /// Both provided by HomeView so a freshly-started conversation, or a tap
    /// on the seller card, can be pushed onto the shared NavigationPath —
    /// this view has no path binding of its own. Default to no-ops for
    /// previews/other call sites.
    var onOpenConversation: (String) -> Void = { _ in }
    var onOpenSeller: (String) -> Void = { _ in }

    @StateObject private var viewModel = ListingDetailViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.loadError || viewModel.listing == nil {
                Text(i18n.t("listing.not_found")).foregroundStyle(.secondary)
            } else if let listing = viewModel.listing {
                content(for: listing)
            }
        }
        .navigationTitle("Annonce")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.listing != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if viewModel.isLoggedIn {
                            Button {
                                viewModel.toggleFavorite()
                            } label: {
                                Image(systemName: viewModel.favorited ? "heart.fill" : "heart")
                                    .foregroundStyle(viewModel.favorited ? Color.soukmarPrimary : .primary)
                            }
                            Button {
                                viewModel.reportOpen = true
                            } label: {
                                Image(systemName: "flag")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.reportOpen) {
            ReportSheet(viewModel: viewModel)
        }
        .task { viewModel.load(id: listingId) }
    }

    @ViewBuilder
    private func content(for listing: ListingDto) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gallery(for: listing)

                VStack(alignment: .leading, spacing: 6) {
                    Text(listing.title).font(.title3.bold())

                    HStack(spacing: 6) {
                        Text(listing.city)
                        Text("·")
                        Text(i18n.timeAgoT(listing.createdAt))
                        Text("·")
                        Text("\(listing.views) \(i18n.t("listing.views"))")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.soukmarTextMuted)

                    priceSection(for: listing)

                    if let cat = categoryConfig(listing.category) {
                        HStack(spacing: 4) {
                            Text(cat.emoji)
                            Text(i18n.tCatalog("cats.\(cat.value)", code: cat.value))
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(cat.bg)
                        .foregroundStyle(cat.fg)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                if !listing.description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(i18n.t("listing.description")).font(.headline)
                        Text(listing.description).foregroundStyle(.primary)
                    }
                    .padding(.horizontal)
                }

                if !listing.attributeValues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(i18n.t("listing.specs_title")).font(.headline)
                        VStack(spacing: 0) {
                            ForEach(listing.attributeValues) { av in
                                specRow(av)
                                if av.id != listing.attributeValues.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }

                contactCard(for: listing).padding(.horizontal)

                if let seller = listing.user {
                    sellerCard(seller).padding(.horizontal)
                }

                if viewModel.isLoggedIn {
                    reviewSection
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func contactCard(for listing: ListingDto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = viewModel.chatMessage {
                ErrorBanner(message: message)
            }
            if !viewModel.isLoggedIn {
                Text(i18n.t("listing.login_contact"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let phone = listing.phone {
                    HStack {
                        Text("📞 \(phone)").fontWeight(.semibold).foregroundStyle(.green)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if let whatsapp = listing.whatsapp, let url = URL(string: "https://wa.me/\(whatsapp)") {
                    Link(destination: url) {
                        Text("💬 WhatsApp · \(whatsapp)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    viewModel.startChat(onNavigate: onOpenConversation)
                } label: {
                    if viewModel.chatStarting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("💬 \(i18n.t("listing.contact"))").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .disabled(viewModel.chatStarting)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sellerCard(_ seller: ListingUserDto) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.soukmarPrimary)
                .frame(width: 44, height: 44)
                .overlay(Text(seller.name.prefix(1).uppercased()).foregroundStyle(.white).fontWeight(.bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(seller.name).font(.subheadline.weight(.semibold))
                if let city = seller.city {
                    Text(city).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(i18n.t("listing.seller_listings")) {
                onOpenSeller(seller.id)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func gallery(for listing: ListingDto) -> some View {
        if listing.images.isEmpty {
            Rectangle()
                .fill(categoryConfig(listing.category)?.bg ?? Color(hex: 0xF1F5F9))
                .aspectRatio(1.3, contentMode: .fit)
                .overlay(Text(categoryConfig(listing.category)?.emoji ?? "📦").font(.system(size: 48)))
        } else {
            TabView {
                ForEach(listing.images, id: \.self) { urlString in
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(.secondarySystemBackground))
                            }
                        }
                        .clipped()
                    }
                }
            }
            .tabViewStyle(.page)
            .aspectRatio(1.3, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func priceSection(for listing: ListingDto) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            if let price = listing.price {
                let (amount, currency) = formatPriceParts(price, currency: listing.currency)
                Text(amount).font(.title2.bold())
                Text(currency).font(.subheadline.weight(.semibold)).foregroundStyle(Color.soukmarTextMuted)
            } else {
                Text(i18n.t("listing.negotiate")).font(.title2.bold())
            }
        }
        if let pct = viewModel.priceComparisonPct {
            let good = pct < 0
            Text(good
                ? "📉 \(i18n.t("listing.price_below", ["pct": "\(-pct)"]))"
                : "📈 \(i18n.t("listing.price_above", ["pct": "\(pct)"]))"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(good ? .green : (pct > 10 ? .red : Color.soukmarTextMuted))
        }
    }

    private func specRow(_ av: ListingAttributeValueDto) -> some View {
        let def = av.attributeDefinition
        let label = def.map { i18n.tCatalog("attrs.\($0.code)", code: $0.code) } ?? ""
        let value: String = {
            switch def?.type {
            case "BOOLEAN": return (av.valueBoolean == true) ? i18n.t("common.yes") : i18n.t("common.no")
            case "NUMBER":
                guard let n = av.valueNumber else { return "" }
                return n == n.rounded() ? String(Int(n)) : String(n)
            case "SELECT": return av.valueText.map { i18n.tCatalog("attrs.opts.\($0)", code: $0) } ?? ""
            default: return av.valueText ?? ""
            }
        }()
        return HStack {
            Text(label).foregroundStyle(Color.soukmarTextMuted)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    @ViewBuilder
    private var reviewSection: some View {
        if viewModel.reviewSubmitted {
            SuccessBanner(message: i18n.t("listing.review_thanks")).padding(.horizontal)
        } else if viewModel.canReview {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.showReviewForm {
                    Text(i18n.t("listing.leave_review")).font(.headline)
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= viewModel.reviewRating ? "star.fill" : "star")
                                .foregroundStyle(Color.soukmarGold)
                                .onTapGesture { viewModel.reviewRating = star }
                        }
                    }
                    TextField(i18n.t("listing.review_placeholder"), text: $viewModel.reviewComment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    Button {
                        viewModel.submitReview()
                    } label: {
                        if viewModel.reviewSubmitting {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Text(i18n.t("listing.submit_review")).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .disabled(viewModel.reviewSubmitting)
                } else {
                    Button(i18n.t("listing.leave_review")) { viewModel.showReviewForm = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct ReportSheet: View {
    @ObservedObject var viewModel: ListingDetailViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(i18n.t("report.form_title"))
                    .font(.headline)
                if let error = viewModel.reportError {
                    ErrorBanner(message: error)
                }
                TextField(i18n.t("report.placeholder"), text: $viewModel.reportReason, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
                Button {
                    viewModel.submitReport()
                } label: {
                    if viewModel.reportSubmitting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text(i18n.t("report.submit")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.soukmarPrimary)
                .disabled(viewModel.reportSubmitting)
                Spacer()
            }
            .padding()
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(i18n.t("common.cancel")) { viewModel.cancelReport() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ListingDetailView(listingId: "preview") }
}
