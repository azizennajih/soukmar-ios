import SwiftUI

private let FILTERS = ["PENDING", "RESOLVED", "DISMISSED", "ALL"]

private func statusLabel(_ status: String, _ i18n: I18nRepository) -> String {
    switch status {
    case "PENDING": return i18n.t("admin.reports_status_pending")
    case "RESOLVED": return i18n.t("admin.reports_status_resolved")
    case "DISMISSED": return i18n.t("admin.reports_status_dismissed")
    default: return i18n.t("admin.filter_all")
    }
}

/// Mirrors soukmar-android's AdminScreen — reports moderation queue with
/// filter pills (live counts), resolve/dismiss with an optional note.
struct AdminView: View {
    var onOpenListing: (String) -> Void

    @StateObject private var viewModel = AdminViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
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
                    Text("Impossible de charger les signalements.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredReports.isEmpty {
                    emptyState
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
        .navigationTitle(i18n.t("admin.reports_title"))
        .navigationBarTitleDisplayMode(.inline)
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
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🚩").font(.system(size: 40))
            Text(i18n.t("admin.reports_empty")).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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
                    Text("📌 \(listing.title)").font(.subheadline.weight(.semibold)).foregroundStyle(Color.soukmarPrimary)
                }
                .buttonStyle(.plain)
            }

            Text(report.reason).font(.subheadline)

            if let note = report.adminNote, !note.isEmpty {
                Text("📝 \(note)").font(.caption).foregroundStyle(.secondary)
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

#Preview {
    NavigationStack { AdminView(onOpenListing: { _ in }) }
}
