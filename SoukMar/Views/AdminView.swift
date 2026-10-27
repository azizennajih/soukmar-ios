import SwiftUI

private let FILTERS = ["PENDING", "RESOLVED", "DISMISSED", "ALL"]
private let ID_VERIFICATION_FILTERS = ["PENDING", "APPROVED", "REJECTED", "ALL"]
private let BOOST_REQUEST_FILTERS = ["PENDING", "APPROVED", "REJECTED", "ALL"]

private func statusLabel(_ status: String, _ i18n: I18nRepository) -> String {
    switch status {
    case "PENDING": return i18n.t("admin.reports_status_pending")
    case "RESOLVED": return i18n.t("admin.reports_status_resolved")
    case "DISMISSED": return i18n.t("admin.reports_status_dismissed")
    case "APPROVED": return i18n.t("admin.reports_status_approved")
    case "REJECTED": return i18n.t("admin.reports_status_rejected")
    default: return i18n.t("admin.filter_all")
    }
}

/// Same order as the web dashboard's tabs.
private enum AdminTab { case overview, moderation, listings, users, visitors, revenue, reports, idVerifications, boostRequests, security }

/// Mirrors soukmar-android's AdminScreen — reports moderation queue with
/// filter pills (live counts), resolve/dismiss with an optional note, plus
/// (new) a second "Vérifications" tab for the free ID-verification review
/// queue, built with the exact same filter-pill/alert-with-note pattern.
struct AdminView: View {
    var onOpenListing: (String) -> Void

    @StateObject private var viewModel = AdminViewModel()
    @StateObject private var dashboard = AdminDashboardViewModel()
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var tab: AdminTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            AdminScopeBar(viewModel: dashboard)
            // Ten long labels do not fit a segmented control on a phone: scrolling pills like the filter rows below.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tabPill(.overview, i18n.t("admin.tab_overview"))
                    tabPill(.moderation, i18n.t("moderation.title"))
                    tabPill(.listings, i18n.t("admin.tab_listings"))
                    tabPill(.users, i18n.t("admin.tab_users"))
                    tabPill(.visitors, i18n.t("admin.tab_visitors"))
                    tabPill(.revenue, i18n.t("admin.tab_revenue"))
                    tabPill(.reports, i18n.t("admin.tab_reports"))
                    tabPill(.idVerifications, i18n.t("admin.tab_id_verifications"))
                    tabPill(.boostRequests, i18n.t("admin.tab_boost_requests"))
                    tabPill(.security, i18n.t("admin.tab_security"))
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            switch tab {
            case .overview: AdminOverviewView(viewModel: dashboard)
            case .listings: AdminListingsView(viewModel: dashboard, onOpenListing: onOpenListing)
            case .users: AdminUsersView(viewModel: dashboard)
            case .visitors: AdminVisitorsView(viewModel: dashboard)
            case .revenue: AdminRevenueView(viewModel: dashboard)
            case .security: AdminSecurityView(viewModel: dashboard)
            case .moderation: ModerationView(onOpenListing: onOpenListing)
            case .reports: reportsSection
            case .idVerifications: idVerificationsSection
            case .boostRequests: boostRequestsSection
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
            dashboard.start()
        }
        .onChange(of: tab) { newTab in
            if newTab == .idVerifications { viewModel.loadIdVerificationsIfNeeded() }
            if newTab == .boostRequests { viewModel.loadBoostRequestsIfNeeded() }
        }
    }

    private func tabPill(_ value: AdminTab, _ title: String) -> some View {
        Button {
            tab = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(tab == value ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                .foregroundStyle(tab == value ? Color.soukmarPrimary : .primary)
                .clipShape(Capsule())
        }
    }

    private var navigationTitle: String {
        switch tab {
        case .overview: return i18n.t("admin.title")
        case .listings: return i18n.t("admin.listings_title")
        case .users: return i18n.t("admin.users_title")
        case .visitors: return i18n.t("admin.tab_visitors")
        case .revenue: return i18n.t("admin.revenue_title")
        case .security: return i18n.t("admin.security_title")
        case .moderation: return i18n.t("moderation.title")
        case .reports: return i18n.t("admin.reports_title")
        case .idVerifications: return i18n.t("admin.id_verifications_title")
        case .boostRequests: return i18n.t("admin.boost_requests_title")
        }
    }

    @ViewBuilder
    private var reportsSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FILTERS, id: \.self) { f in
                        Button {
                            viewModel.filter = f
                        } label: {
                            Text("\(statusLabel(f, i18n)) (\(viewModel.countFor(f)))")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(viewModel.filter == f ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                                .foregroundStyle(viewModel.filter == f ? Color.soukmarPrimary : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Group {
                if viewModel.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.loadError {
                    Text(i18n.t("common.error"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredReports.isEmpty {
                    emptyState(icon: "flag", text: i18n.t("admin.reports_empty"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.filteredReports) { report in
                                ReportCard(
                                    report: report,
                                    onOpenListing: onOpenListing,
                                    onResolve: { viewModel.openAction(report, status: "RESOLVED") },
                                    onDismiss: { viewModel.openAction(report, status: "DISMISSED") }
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .alert(
            viewModel.actionStatus == "RESOLVED" ? i18n.t("admin.reports_resolve") : i18n.t("admin.reports_dismiss"),
            isPresented: Binding(
                get: { viewModel.actionTarget != nil },
                set: { if !$0 { viewModel.cancelAction() } }
            )
        ) {
            TextField(i18n.t("admin.reports_note_prompt"), text: $viewModel.actionNote)
            Button(viewModel.actionSubmitting ? "…" : i18n.t("common.save")) { viewModel.confirmAction() }
                .disabled(viewModel.actionSubmitting)
            Button(i18n.t("common.cancel"), role: .cancel) { viewModel.cancelAction() }
        } message: {
            Text(i18n.t("admin.reports_note_prompt"))
        }
    }

    @ViewBuilder
    private var idVerificationsSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ID_VERIFICATION_FILTERS, id: \.self) { f in
                        Button {
                            viewModel.idVerificationFilter = f
                        } label: {
                            Text("\(statusLabel(f, i18n)) (\(viewModel.countForIdVerification(f)))")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(viewModel.idVerificationFilter == f ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                                .foregroundStyle(viewModel.idVerificationFilter == f ? Color.soukmarPrimary : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Group {
                if viewModel.idVerificationsLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.idVerificationsLoadError {
                    Text(i18n.t("common.error"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredIdVerifications.isEmpty {
                    emptyState(icon: "person.text.rectangle", text: i18n.t("admin.id_verifications_empty"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.filteredIdVerifications) { verification in
                                IdVerificationCard(
                                    verification: verification,
                                    onApprove: { viewModel.openIdVerificationAction(verification, status: "APPROVED") },
                                    onReject: { viewModel.openIdVerificationAction(verification, status: "REJECTED") }
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .alert(
            viewModel.idVerificationActionStatus == "APPROVED" ? i18n.t("admin.id_verifications_approve") : i18n.t("admin.id_verifications_reject"),
            isPresented: Binding(
                get: { viewModel.idVerificationActionTarget != nil },
                set: { if !$0 { viewModel.cancelIdVerificationAction() } }
            )
        ) {
            TextField(i18n.t("admin.id_verification_note_prompt"), text: $viewModel.idVerificationActionNote)
            Button(viewModel.idVerificationActionSubmitting ? "…" : i18n.t("common.save")) { viewModel.confirmIdVerificationAction() }
                .disabled(viewModel.idVerificationActionSubmitting)
            Button(i18n.t("common.cancel"), role: .cancel) { viewModel.cancelIdVerificationAction() }
        } message: {
            Text(i18n.t("admin.id_verification_note_prompt"))
        }
    }

    @ViewBuilder
    private var boostRequestsSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BOOST_REQUEST_FILTERS, id: \.self) { f in
                        Button {
                            viewModel.boostRequestFilter = f
                        } label: {
                            Text("\(statusLabel(f, i18n)) (\(viewModel.countForBoostRequest(f)))")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(viewModel.boostRequestFilter == f ? Color.soukmarPrimaryLight : Color(.secondarySystemBackground))
                                .foregroundStyle(viewModel.boostRequestFilter == f ? Color.soukmarPrimary : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Group {
                if viewModel.boostRequestsLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.boostRequestsLoadError {
                    Text(i18n.t("common.error"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredBoostRequests.isEmpty {
                    emptyState(icon: "bolt.fill", text: i18n.t("admin.boost_requests_empty"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.filteredBoostRequests) { request in
                                BoostRequestCard(
                                    request: request,
                                    onOpenListing: onOpenListing,
                                    onApprove: { viewModel.openBoostAction(request, status: "APPROVED") },
                                    onReject: { viewModel.openBoostAction(request, status: "REJECTED") }
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .alert(
            viewModel.boostActionStatus == "APPROVED" ? i18n.t("admin.boost_requests_approve") : i18n.t("admin.boost_requests_reject"),
            isPresented: Binding(
                get: { viewModel.boostActionTarget != nil },
                set: { if !$0 { viewModel.cancelBoostAction() } }
            )
        ) {
            TextField(i18n.t("admin.boost_request_note_prompt"), text: $viewModel.boostActionNote)
            Button(viewModel.boostActionSubmitting ? "…" : i18n.t("common.save")) { viewModel.confirmBoostAction() }
                .disabled(viewModel.boostActionSubmitting)
            Button(i18n.t("common.cancel"), role: .cancel) { viewModel.cancelBoostAction() }
        } message: {
            Text(i18n.t("admin.boost_request_note_prompt"))
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct IdVerificationCard: View {
    let verification: IdVerificationAdminDto
    let onApprove: () -> Void
    let onReject: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    private var statusColors: (bg: Color, fg: Color) {
        switch verification.status {
        case "PENDING": return (Color.soukmarGoldLight, Color.soukmarGold)
        case "APPROVED": return (Color.green.opacity(0.12), .green)
        default: return (Color.red.opacity(0.1), .red)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusLabel(verification.status, i18n))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColors.bg)
                    .foregroundStyle(statusColors.fg)
                    .clipShape(Capsule())
                Text(i18n.timeAgoT(verification.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("admin.id_verifications_user")).font(.caption2).foregroundStyle(.secondary)
                Text("\(verification.user?.name ?? "?") · \(verification.user?.email ?? "")").font(.subheadline.weight(.medium))
            }

            HStack(spacing: 16) {
                if let url = URL(string: verification.idImageUrl) {
                    VStack(spacing: 4) {
                        thumbnail(url)
                        Text(i18n.t("admin.id_verifications_id_photo")).font(.caption2).foregroundStyle(Color.soukmarPrimary)
                    }
                }
                if let url = URL(string: verification.selfieImageUrl) {
                    VStack(spacing: 4) {
                        thumbnail(url)
                        Text(i18n.t("admin.id_verifications_selfie_photo")).font(.caption2).foregroundStyle(Color.soukmarPrimary)
                    }
                }
            }

            if let note = verification.adminNote, !note.isEmpty {
                Label(note, systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
            }

            if verification.status == "PENDING" {
                HStack(spacing: 8) {
                    Button(i18n.t("admin.id_verifications_approve"), action: onApprove)
                        .buttonStyle(.borderedProminent).tint(Color.soukmarPrimary)
                    Button(i18n.t("admin.id_verifications_reject"), action: onReject)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func thumbnail(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color(.tertiarySystemBackground))
                    .overlay(ProgressView())
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ReportCard: View {
    let report: AdminReportDto
    let onOpenListing: (String) -> Void
    let onResolve: () -> Void
    let onDismiss: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    private var statusColors: (bg: Color, fg: Color) {
        switch report.status {
        case "PENDING": return (Color.soukmarGoldLight, Color.soukmarGold)
        case "RESOLVED": return (Color.green.opacity(0.12), .green)
        default: return (Color.red.opacity(0.1), .red)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusLabel(report.status, i18n))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColors.bg)
                    .foregroundStyle(statusColors.fg)
                    .clipShape(Capsule())
                Text(i18n.timeAgoT(report.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("admin.reports_reporter")).font(.caption2).foregroundStyle(.secondary)
                Text("\(report.reporter?.name ?? "?") · \(report.reporter?.email ?? "")").font(.subheadline.weight(.medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("admin.reports_reported")).font(.caption2).foregroundStyle(.secondary)
                Text("\(report.reported?.name ?? "?") · \(report.reported?.email ?? "")").font(.subheadline.weight(.medium))
            }

            if let listing = report.listing {
                Button {
                    onOpenListing(listing.id)
                } label: {
                    Label(listing.title, systemImage: "link").font(.subheadline.weight(.semibold)).foregroundStyle(Color.soukmarPrimary)
                }
                .buttonStyle(.plain)
            }

            Text(report.reason).font(.subheadline)

            if let note = report.adminNote, !note.isEmpty {
                Label(note, systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
            }

            if report.status == "PENDING" {
                HStack(spacing: 8) {
                    Button(i18n.t("admin.reports_resolve"), action: onResolve)
                        .buttonStyle(.borderedProminent).tint(Color.soukmarPrimary)
                    Button(i18n.t("admin.reports_dismiss"), action: onDismiss)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Mirrors the web admin's Boosts tab: listing/seller refs, the requested
/// tier ids (translated via boost.tier_<id>_name) + quoted price, status
/// badge, Approve/Reject only while PENDING. Approving is the only place
/// that actually activates the effects (see backend's applyBoostTiers) —
/// the request itself never touches money, since no payment processor
/// exists yet.
private struct BoostRequestCard: View {
    let request: BoostRequestDto
    let onOpenListing: (String) -> Void
    let onApprove: () -> Void
    let onReject: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    private var statusColors: (bg: Color, fg: Color) {
        switch request.status {
        case "PENDING": return (Color.soukmarGoldLight, Color.soukmarGold)
        case "APPROVED": return (Color.green.opacity(0.12), .green)
        default: return (Color.red.opacity(0.1), .red)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusLabel(request.status, i18n))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColors.bg)
                    .foregroundStyle(statusColors.fg)
                    .clipShape(Capsule())
                Text(i18n.timeAgoT(request.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("admin.boost_requests_listing")).font(.caption2).foregroundStyle(.secondary)
                Button {
                    onOpenListing(request.listingId)
                } label: {
                    Label(request.listing?.title ?? "?", systemImage: "link").font(.subheadline.weight(.semibold)).foregroundStyle(Color.soukmarPrimary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("admin.boost_requests_seller")).font(.caption2).foregroundStyle(.secondary)
                Text("\(request.user?.name ?? "?") · \(request.user?.email ?? "")").font(.subheadline.weight(.medium))
            }

            let tierNames = request.tiers.map { i18n.t("boost.tier_\($0)_name") }.joined(separator: ", ")
            let (amount, currency) = formatPriceParts(request.totalPrice, currency: request.currency, lang: i18n.currentLang)
            Text("\(i18n.t("admin.boost_requests_tiers")): \(tierNames)  ·  \(i18n.t("admin.boost_requests_price")): \(amount) \(currency)")
                .font(.subheadline)

            if let note = request.adminNote, !note.isEmpty {
                Label(note, systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
            }

            if request.status == "PENDING" {
                HStack(spacing: 8) {
                    Button(i18n.t("admin.boost_requests_approve"), action: onApprove)
                        .buttonStyle(.borderedProminent).tint(Color.soukmarPrimary)
                    Button(i18n.t("admin.boost_requests_reject"), action: onReject)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack { AdminView(onOpenListing: { _ in }) }
}
