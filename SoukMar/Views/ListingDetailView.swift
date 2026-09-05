import SwiftUI

/// Mirrors soukmar-android's ListingDetailScreen — gallery, price with
/// average-price comparison, attributes, favorites, and reporting. "Contacter
/// le vendeur" (chat) and the seller profile link are intentionally left out:
/// both are later iOS phases (Android Phase 5/9 equivalents).
struct ListingDetailView: View {
    let listingId: String
    @StateObject private var viewModel = ListingDetailViewModel()

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.loadError || viewModel.listing == nil {
                Text("Annonce introuvable.").foregroundStyle(.secondary)
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
                        Text(timeAgo(listing.createdAt))
                        Text("·")
                        Text("\(listing.views) vues")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.soukmarTextMuted)

                    priceSection(for: listing)

                    if let cat = categoryConfig(listing.category) {
                        HStack(spacing: 4) {
                            Text(cat.emoji)
                            Text(cat.label)
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
                        Text("Description").font(.headline)
                        Text(listing.description).foregroundStyle(.primary)
                    }
                    .padding(.horizontal)
                }

                if !listing.attributeValues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Caractéristiques").font(.headline)
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

                if viewModel.isLoggedIn {
                    reviewSection
                }
            }
            .padding(.vertical)
        }
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
                Text("Prix à négocier").font(.title2.bold())
            }
        }
        if let pct = viewModel.priceComparisonPct {
            let good = pct < 0
            Text(good
                ? "📉 \(-pct)% moins cher que la moyenne"
                : "📈 \(pct)% plus cher que la moyenne"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(good ? .green : (pct > 10 ? .red : Color.soukmarTextMuted))
        }
    }

    private func specRow(_ av: ListingAttributeValueDto) -> some View {
        let def = av.attributeDefinition
        let label = def.map { humanizeCode($0.code) } ?? ""
        let value: String = {
            switch def?.type {
            case "BOOLEAN": return (av.valueBoolean == true) ? "Oui" : "Non"
            case "NUMBER":
                guard let n = av.valueNumber else { return "" }
                return n == n.rounded() ? String(Int(n)) : String(n)
            case "SELECT": return av.valueText.map(humanizeCode) ?? ""
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
            SuccessBanner(message: "Merci pour votre évaluation !").padding(.horizontal)
        } else if viewModel.canReview {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.showReviewForm {
                    Text("Laisser une évaluation").font(.headline)
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= viewModel.reviewRating ? "star.fill" : "star")
                                .foregroundStyle(Color.soukmarGold)
                                .onTapGesture { viewModel.reviewRating = star }
                        }
                    }
                    TextField("Commentaire (optionnel)", text: $viewModel.reviewComment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    Button {
                        viewModel.submitReview()
                    } label: {
                        if viewModel.reviewSubmitting {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Text("Envoyer").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.soukmarPrimary)
                    .disabled(viewModel.reviewSubmitting)
                } else {
                    Button("Laisser une évaluation") { viewModel.showReviewForm = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct ReportSheet: View {
    @ObservedObject var viewModel: ListingDetailViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pourquoi signalez-vous cette annonce ?")
                    .font(.headline)
                if let error = viewModel.reportError {
                    ErrorBanner(message: error)
                }
                TextField("Décrivez la raison (10 caractères min.)", text: $viewModel.reportReason, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
                Button {
                    viewModel.submitReport()
                } label: {
                    if viewModel.reportSubmitting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Envoyer le signalement").frame(maxWidth: .infinity)
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
                    Button("Annuler") { viewModel.cancelReport() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ListingDetailView(listingId: "preview") }
}
