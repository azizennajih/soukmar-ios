import SwiftUI
import UIKit

/// Mirrors the web's /mes-donnees page and soukmar-android's MesDonneesScreen (without the cookie section:
/// the app has no cookie banner).
struct MesDonneesView: View {
    @StateObject private var viewModel = MesDonneesViewModel()
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error = viewModel.errorMessage { ErrorBanner(message: error) }
                emailCard
                blockedCard
                exportCard
            }
            .padding(16)
        }
        .navigationTitle(i18n.t("mes_donnees.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .sheet(isPresented: Binding(get: { viewModel.exportFile != nil }, set: { if !$0 { viewModel.exportFile = nil } })) {
            if let url = viewModel.exportFile { ActivityShareSheet(items: [url]) }
        }
    }

    private var emailCard: some View {
        card {
            Text(i18n.t("mes_donnees.email_title")).font(.headline)
            Text(i18n.t("mes_donnees.email_intro")).font(.caption).foregroundStyle(.secondary)
            if let prefs = viewModel.prefs {
                prefToggle(i18n.t("mes_donnees.email_messages"), \.emailMessages, prefs.emailMessages)
                prefToggle(i18n.t("mes_donnees.email_saved_searches"), \.emailSavedSearches, prefs.emailSavedSearches)
                prefToggle(i18n.t("mes_donnees.email_listing_reminders"), \.emailListingReminders, prefs.emailListingReminders)
                Text(i18n.t("mes_donnees.email_always")).font(.caption2).foregroundStyle(.secondary)
                Divider()
                prefToggle(i18n.t("mes_donnees.email_marketing"), \.emailMarketing, prefs.emailMarketing)
                Text(i18n.t("mes_donnees.marketing_hint")).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func prefToggle(_ label: String, _ keyPath: WritableKeyPath<EmailPreferencesDto, Bool>, _ value: Bool) -> some View {
        Toggle(label, isOn: Binding(get: { value }, set: { viewModel.setPref(keyPath, $0) }))
            .font(.subheadline)
            .tint(Color.soukmarPrimary)
    }

    private var blockedCard: some View {
        card {
            Text(i18n.t("mes_donnees.blocked_title")).font(.headline)
            if let list = viewModel.blocked {
                if list.isEmpty {
                    Text(i18n.t("mes_donnees.blocked_empty")).font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(list) { user in
                    HStack {
                        Text(String((user.name ?? "").prefix(1)).uppercased())
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.soukmarPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.soukmarPrimaryLight)
                            .clipShape(Circle())
                        Text(user.name ?? "").font(.subheadline)
                        Spacer()
                        Button(i18n.t("mes_donnees.unblock")) { viewModel.unblock(user) }
                            .buttonStyle(.bordered)
                            .font(.footnote)
                    }
                }
            }
        }
    }

    private var exportCard: some View {
        card {
            Text(i18n.t("mes_donnees.export_title")).font(.headline)
            Text(i18n.t("mes_donnees.export_intro")).font(.caption).foregroundStyle(.secondary)
            Button {
                viewModel.prepareExport()
            } label: {
                Text(i18n.t("mes_donnees.export_btn")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.soukmarPrimary)
            .disabled(viewModel.exporting)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// The system share sheet ("Save to Files", AirDrop, mail, …) for the exported file.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
