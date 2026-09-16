import SwiftUI

/// Same palette as soukmar-android's ui/theme/Color.kt and the web's
/// styles.scss CSS variables — keep these three in sync.
extension Color {
    static let soukmarPrimary = Color(red: 0xD9 / 255, green: 0x3D / 255, blue: 0x4A / 255)
    static let soukmarPrimaryLight = Color(red: 0xFE / 255, green: 0xF1 / 255, blue: 0xF2 / 255)
    static let soukmarGold = Color(red: 0xC9 / 255, green: 0x94 / 255, blue: 0x1A / 255)
    static let soukmarGoldLight = Color(red: 0xFE / 255, green: 0xF6 / 255, blue: 0xE4 / 255)
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
                Text("SouqMar").fontWeight(.black)
                Text("24").fontWeight(.black).foregroundStyle(Color.soukmarPrimary)
            }
            .font(.title3)
        }
    }
}

/// Mirrors soukmar-android's AccountTypeSelector composable — two side-by-side
/// toggle buttons for the PRIVATE/BUSINESS choice required at registration
/// (and, in a later phase, editable from the profile).
struct AccountTypeSelector: View {
    @Binding var selected: String
    let options: [(value: String, label: String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                let isSelected = selected == option.value
                Button {
                    selected = option.value
                } label: {
                    Text(option.label)
                        .fontWeight(isSelected ? .bold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .foregroundStyle(isSelected ? Color.soukmarPrimary : .primary)
                .background(isSelected ? Color.soukmarPrimaryLight : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.soukmarPrimary : Color(.systemGray4), lineWidth: 1.5)
                )
            }
        }
    }
}

/// Secure field with a show/hide eye toggle that auto-hides again after 8s —
/// mirrors soukmar-android's `AppTextField(isPassword = true)`, which itself
/// mirrors the web's password-input component. Drop-in replacement for a
/// plain `SecureField`.
struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.trailing, 30)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 10)
        }
        .onChange(of: isVisible) { newValue in
            hideTask?.cancel()
            guard newValue else { return }
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if !Task.isCancelled { isVisible = false }
            }
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
