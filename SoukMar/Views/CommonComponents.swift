import SwiftUI

/// Same palette as soukmar-android's ui/theme/Color.kt and the web's
/// styles.scss CSS variables — keep these three in sync.
extension Color {
    static let soukmarPrimary = Color(red: 0xD9 / 255, green: 0x3D / 255, blue: 0x4A / 255)
    static let soukmarGold = Color(red: 0xC9 / 255, green: 0x94 / 255, blue: 0x1A / 255)
    static let soukmarTextMuted = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
}

struct SoukMarLogo: View {
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.soukmarPrimary)
                .frame(width: 36, height: 36)
                .overlay(Text("S").font(.headline.bold()).foregroundStyle(.white))
            HStack(spacing: 0) {
                Text("Souk").fontWeight(.black)
                Text("Mar").fontWeight(.black).foregroundStyle(Color.soukmarPrimary)
            }
            .font(.title3)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SuccessBanner: View {
    let message: String
    var body: some View {
        Text("✅ \(message)")
            .font(.subheadline)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
