import SwiftUI

private let FILTERS = ["PENDING", "RESOLVED", "DISMISSED", "ALL"]

private func statusLabel(_ status: String) -> String {
    switch status {
    case "PENDING": return "En attente"
    case "RESOLVED": return "Résolu"
    case "DISMISSED": return "Rejeté"
    default: return "Toutes"
    }
}

/// Mirrors soukmar-android's AdminScreen — reports moderation queue with
/// filter pills (live counts), resolve/dismiss with an optional note.
struct AdminView: View {
    var onOpenListing: (String) -> Void

    @StateObject private var viewModel = AdminViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FILTERS, id: \.self) { f in
                        Button {
                            viewModel.filter = f
                        } label: {
                            Text("\(statusLabel(f)) (\(viewModel.countFor(f)))")
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
        .navigationTitle("Signalements")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            viewModel.actionStatus == "RESOLVED" ? "Résoudre le signalement" : "Rejeter le signalement",
            isPresented: Binding(
                get: { viewModel.actionTarget != nil },
                set: { if !$0 { viewModel.cancelAction() } }
            )
        ) {
            TextField("Note interne (optionnel)", text: $viewModel.actionNote)
            Button(viewModel.actionSubmitting ? "Envoi…" : "Confirmer") { viewModel.confirmAction() }
                .disabled(viewModel.actionSubmitting)
            Button("Annuler", role: .cancel) { viewModel.cancelAction() }
        } message: {
            Text("Note interne (optionnel) :")
        }
        .task { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🚩").font(.system(size: 40))
            Text("Aucun signalement pour le moment.").foregroundStyle(.secondary).multilineTextAlignment(.center)
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
                Text(statusLabel(report.status))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColors.bg)
                    .foregroundStyle(statusColors.fg)
                    .clipShape(Capsule())
                Text(timeAgo(report.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Signalé par").font(.caption2).foregroundStyle(.secondary)
                Text("\(report.reporter?.name ?? "?") · \(report.reporter?.email ?? "")").font(.subheadline.weight(.medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Utilisateur signalé").font(.caption2).foregroundStyle(.secondary)
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
                    Button("✅ Résoudre", action: onResolve)
                        .buttonStyle(.borderedProminent).tint(Color.soukmarPrimary)
                    Button("❌ Rejeter", action: onDismiss)
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
