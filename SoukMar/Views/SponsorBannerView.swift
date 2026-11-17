import SwiftUI

/// One advertising banner with the mandatory "Werbung" label (mirrors the web's app-sponsor-banner).
/// A tap opens the link in the browser and reports the click for the aggregate counter.
struct SponsorBannerView: View {
    let banner: SponsorBannerDto
    @ObservedObject private var i18n = I18nRepository.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            SponsorRepository.shared.click(id: banner.id)
            // Only https links are stored by the backend; anything else is not opened.
            if banner.linkUrl.hasPrefix("https://"), let url = URL(string: banner.linkUrl) {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(i18n.t("sponsor.label"))
                    .font(.caption2)
                    .foregroundStyle(Color.soukmarTextMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                AsyncImage(url: URL(string: banner.imageUrl)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color(.systemGray6).frame(height: 80)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(banner.altText?.isEmpty == false ? banner.altText! : i18n.t("sponsor.label"))
    }
}
