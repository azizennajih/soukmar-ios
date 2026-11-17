import SwiftUI

private let LISTING_FILTERS = ["ALL", "ACTIVE", "PENDING", "CHANGES_REQUESTED", "REJECTED", "SUSPENDED", "SOLD", "RESERVED"]
private let SEVERITY_FILTERS = ["ALL", "HIGH", "MEDIUM", "LOW"]
private let ROLES = ["USER", "MODERATOR", "ADMIN"]
/// Statuses of the review workflow: changed only in the moderation tab, never by the plain "publish" button.
private let REVIEW_STATUSES = ["PENDING", "CHANGES_REQUESTED", "REJECTED", "SUSPENDED"]

private func countryLabel(_ code: String?, _ i18n: I18nRepository) -> String {
    guard let code else { return "" }
    if code == "ZZ" { return i18n.t("admin.unknown_country") }
    return Locale(identifier: i18n.currentLang).localizedString(forRegionCode: code) ?? code
}

private func money(_ price: Double, _ currency: String, _ i18n: I18nRepository) -> String {
    let parts = formatPriceParts(price, currency: currency, lang: i18n.currentLang)
    return "\(parts.0) \(parts.1)".trimmingCharacters(in: .whitespaces)
}

private func statusText(_ status: String, _ i18n: I18nRepository) -> String {
    i18n.t("annonces.\(status.lowercased())")
}

private func shortDate(_ iso: String?) -> String {
    guard let iso else { return "" }
    return String(iso.prefix(16)).replacingOccurrences(of: "T", with: " ")
}

/// Switch between the browsing country and every country (web: the header's scope buttons).
struct AdminScopeBar: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        HStack(spacing: 8) {
            scopeButton(
                title: "\(flagEmoji(viewModel.scopeCountry)) \(countryLabel(viewModel.scopeCountry, i18n))",
                selected: !viewModel.allCountries
            ) { viewModel.setScope(all: false) }
            scopeButton(title: "🌐 \(i18n.t("admin.scope_all"))", selected: viewModel.allCountries) { viewModel.setScope(all: true) }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func scopeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? Color.soukmarPrimary : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct KpiTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct BarRow: View {
    let label: String
    let value: Int
    let maxValue: Int
    var color: Color = .soukmarPrimary

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.footnote).lineLimit(1).frame(width: 120, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(color).frame(width: maxValue > 0 ? geo.size.width * CGFloat(value) / CGFloat(maxValue) : 0)
                }
            }
            .frame(height: 8)
            Text("\(value)").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct FilterPills: View {
    let options: [String]
    @Binding var selected: String
    let label: (String) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selected = option
                    } label: {
                        Text(label(option))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(selected == option ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                            .foregroundStyle(selected == option ? Color.soukmarPrimary : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Overview

struct AdminOverviewView: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    KpiTile(label: i18n.t("admin.kpi_total"), value: "\(viewModel.listings.count)")
                    KpiTile(label: i18n.t("admin.kpi_active"), value: "\(viewModel.listings.filter { $0.status == "ACTIVE" }.count)")
                }
                HStack(spacing: 8) {
                    KpiTile(label: i18n.t("admin.kpi_pending"), value: "\(viewModel.listings.filter { $0.status == "PENDING" }.count)")
                    KpiTile(label: i18n.t("admin.kpi_users"), value: "\(viewModel.users.count)")
                    KpiTile(label: i18n.t("admin.kpi_premium"), value: "\(viewModel.premiumListings.count)")
                }
                categoryCard
                activityCard
            }
            .padding()
        }
    }

    private var categoryCard: some View {
        let counts = Dictionary(grouping: viewModel.listings, by: { $0.category }).mapValues { $0.count }
        let rows = CATEGORIES.map { ($0, counts[$0.value] ?? 0) }.sorted { $0.1 > $1.1 }
        let top = rows.first?.1 ?? 0
        return DashboardCard {
            Text(i18n.t("admin.cat_breakdown")).font(.subheadline.weight(.semibold))
            ForEach(rows.indices, id: \.self) { index in
                BarRow(label: i18n.tCatalog("cats.\(rows[index].0.value)", code: rows[index].0.value), value: rows[index].1, maxValue: top)
            }
        }
    }

    private var activityCard: some View {
        DashboardCard {
            Text(i18n.t("admin.activity_title")).font(.subheadline.weight(.semibold))
            if viewModel.activity.isEmpty {
                Text(i18n.t("admin.activity_empty")).font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(viewModel.activity) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("admin.activity_\(item.type)") + (item.country.map { " · \(flagEmoji($0))" } ?? ""))
                        .font(.caption2.weight(.semibold)).foregroundStyle(Color.soukmarPrimary)
                    Text(item.title ?? "").font(.subheadline)
                    if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    Text(shortDate(item.at)).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
            }
        }
    }
}

// MARK: - Listings

struct AdminListingsView: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    var onOpenListing: (String) -> Void
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var toDelete: ListingDto?

    var body: some View {
        VStack(spacing: 0) {
            FilterPills(options: LISTING_FILTERS, selected: $viewModel.listingFilter) {
                $0 == "ALL" ? i18n.t("admin.filter_all") : statusText($0, i18n)
            }
            if viewModel.actionFailed {
                Text(i18n.t("admin.update_error")).font(.footnote).foregroundStyle(.red).padding(.horizontal)
            }
            if viewModel.filteredListings.isEmpty {
                Spacer()
                Text(i18n.t("admin.empty_listings")).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredListings) { listing in
                            row(listing)
                        }
                    }
                    .padding()
                }
            }
        }
        .alert(
            toDelete.map { i18n.t("admin.confirm_delete_listing", ["title": $0.title]) } ?? "",
            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })
        ) {
            Button("OK", role: .destructive) {
                if let listing = toDelete { viewModel.deleteListing(listing) }
                toDelete = nil
            }
            Button(i18n.t("common.cancel"), role: .cancel) { toDelete = nil }
        }
    }

    private func row(_ listing: ListingDto) -> some View {
        DashboardCard {
            Button {
                onOpenListing(listing.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    let price = listing.price.map { " · " + money($0, listing.currency, i18n) } ?? ""
                    Text("\(listing.user?.name ?? "") · \(listing.city) · \(flagEmoji(listing.country))\(price)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            HStack {
                Text(statusText(listing.status, i18n)).font(.caption.weight(.semibold)).foregroundStyle(Color(.systemBlue))
                Spacer()
                if listing.status != "ACTIVE" && !REVIEW_STATUSES.contains(listing.status) {
                    Button(i18n.t("annonces.active")) { viewModel.setListingStatus(listing, status: "ACTIVE") }.font(.caption)
                }
                Button(listing.isPremium ? "★ Premium" : "☆ Premium") { viewModel.togglePremium(listing) }
                    .font(.caption)
                    .foregroundStyle(listing.isPremium ? Color.soukmarGold : .secondary)
                Button("✕") { toDelete = listing }.font(.caption).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Users

struct AdminUsersView: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(spacing: 0) {
            TextField(i18n.t("admin.search_users"), text: $viewModel.userSearch)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
            if viewModel.actionFailed {
                Text(i18n.t("admin.update_error")).font(.footnote).foregroundStyle(.red).padding(.horizontal)
            }
            if viewModel.filteredUsers.isEmpty {
                Spacer()
                Text(i18n.t("admin.empty_users")).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredUsers) { user in
                            userCard(user)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "ADMIN": return i18n.t("profil.role_admin")
        case "MODERATOR": return i18n.t("profil.role_mod")
        default: return i18n.t("profil.role_user")
        }
    }

    private func userCard(_ user: AdminUserDto) -> some View {
        DashboardCard {
            Text(user.name ?? "").font(.subheadline.weight(.semibold))
            Text(user.email ?? "").font(.caption).foregroundStyle(.secondary)
            let place = [user.city, user.country.map { "\(flagEmoji($0)) \(countryLabel($0, i18n))" }, "\(user.listingCount?.listings ?? 0) \(i18n.t("admin.col_listings"))"]
                .compactMap { $0 }.joined(separator: " · ")
            Text(place).font(.caption).foregroundStyle(.secondary)
            Menu {
                ForEach(ROLES, id: \.self) { role in
                    Button(roleLabel(role)) {
                        if role != user.role { viewModel.setUserRole(user, role: role) }
                    }
                }
            } label: {
                Text("\(roleLabel(user.role)) ▾")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Visitors

struct AdminVisitorsView: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        if let analytics = viewModel.analytics {
            let daily = analytics.daily ?? []
            let byCountry = analytics.byCountry ?? []
            let dailyMax = max(daily.map { $0.visitors ?? 0 }.max() ?? 0, 1)
            let countryMax = byCountry.map { $0.visitors ?? 0 }.max() ?? 0
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        KpiTile(label: i18n.t("admin.visitors_active_now"), value: "\(analytics.activeNow?.total ?? 0)")
                        KpiTile(label: i18n.t("admin.visitors_today"), value: "\(analytics.today?.total ?? 0)")
                        KpiTile(label: i18n.t("admin.visitors_by_country"), value: "\(byCountry.count)")
                    }
                    DashboardCard {
                        Text(i18n.t("admin.visitors_daily")).font(.subheadline.weight(.semibold))
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(daily.indices, id: \.self) { index in
                                Rectangle()
                                    .fill(Color.soukmarPrimary)
                                    .frame(height: max(2, 80 * CGFloat(daily[index].visitors ?? 0) / CGFloat(dailyMax)))
                            }
                        }
                        .frame(height: 80, alignment: .bottom)
                        Text(i18n.t("admin.visitors_period", ["days": "\(analytics.days ?? 30)"])).font(.caption2).foregroundStyle(.secondary)
                    }
                    DashboardCard {
                        Text(i18n.t("admin.visitors_by_country")).font(.subheadline.weight(.semibold))
                        ForEach(byCountry.indices, id: \.self) { index in
                            let item = byCountry[index]
                            BarRow(
                                label: (item.country == "ZZ" ? "" : flagEmoji(item.country) + " ") + countryLabel(item.country, i18n),
                                value: item.visitors ?? 0, maxValue: countryMax, color: Color(.systemBlue)
                            )
                        }
                    }
                    Text(i18n.t("admin.visitors_privacy")).font(.caption2).foregroundStyle(.secondary)
                }
                .padding()
            }
        } else {
            VStack {
                Spacer()
                Text(i18n.t("admin.activity_empty")).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

// MARK: - Revenue

struct AdminRevenueView: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    /// 99 per premium listing, in the month it was created (same flat price the web dashboard assumes).
    private func monthlyRevenue(_ premium: [ListingDto]) -> [Int] {
        var byMonth = [Int](repeating: 0, count: 12)
        for listing in premium {
            let chars = Array(listing.createdAt)
            if chars.count >= 7, let month = Int(String(chars[5...6])), (1...12).contains(month) { byMonth[month - 1] += 99 }
        }
        return byMonth
    }

    var body: some View {
        let premium = viewModel.premiumListings
        let byMonth = monthlyRevenue(premium)
        let monthMax = max(byMonth.max() ?? 0, 1)
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    KpiTile(label: i18n.t("admin.revenue_total"), value: money(Double(premium.count) * 99, viewModel.revenueCurrency, i18n))
                    KpiTile(label: i18n.t("admin.revenue_active"), value: "\(premium.count)")
                }
                DashboardCard {
                    Text(i18n.t("admin.revenue_chart", ["currency": viewModel.revenueCurrency])).font(.subheadline.weight(.semibold))
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(byMonth.indices, id: \.self) { index in
                            Rectangle()
                                .fill(Color.soukmarGold)
                                .frame(height: max(2, 80 * CGFloat(byMonth[index]) / CGFloat(monthMax)))
                        }
                    }
                    .frame(height: 80, alignment: .bottom)
                }
                if premium.isEmpty {
                    Text(i18n.t("admin.empty_premium")).foregroundStyle(.secondary)
                }
                ForEach(premium) { listing in
                    DashboardCard {
                        Text(listing.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        Text("\(listing.user?.name ?? "") · \(money(99, viewModel.revenueCurrency, i18n))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Security

struct AdminSecurityView: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(spacing: 0) {
            Text(i18n.t("admin.security_sub")).font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 8)
            FilterPills(options: SEVERITY_FILTERS, selected: $viewModel.severityFilter) {
                $0 == "ALL" ? i18n.t("admin.filter_all") : $0
            }
            if viewModel.filteredSecurity.isEmpty {
                Spacer()
                Text(i18n.t("admin.security_empty")).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredSecurity) { event in
                            eventCard(event)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func severityColor(_ severity: String?) -> Color {
        switch severity {
        case "HIGH": return .red
        case "MEDIUM": return Color.soukmarGold
        default: return .green
        }
    }

    private func eventCard(_ event: SecurityEventDto) -> some View {
        let key = "admin.sec_\(event.type.lowercased())"
        let translated = i18n.t(key)
        return DashboardCard {
            HStack(spacing: 8) {
                Text(event.severity ?? "").font(.caption2.weight(.bold)).foregroundStyle(severityColor(event.severity))
                Text(translated == key ? event.type : translated).font(.subheadline.weight(.semibold))
            }
            if let detail = event.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            let parts = [event.user?.name.map { "\(i18n.t("admin.security_user")): \($0)" }, event.ip, shortDate(event.createdAt)]
                .compactMap { $0 }.filter { !$0.isEmpty }
            Text(parts.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
