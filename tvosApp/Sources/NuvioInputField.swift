import SwiftUI

/// A native tvOS text/secure field that integrates cleanly with the Siri Remote,
/// system keyboard, and high-contrast tvOS focus engine.
struct NuvioInputField: View {
    let title: String
    var prompt: String? = nil
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isFocused ? Color.black : NuvioDesignTokens.Colors.secondaryText)
            }
            if isSecure {
                SecureField(prompt ?? title, text: $text)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(isFocused ? Color.black : NuvioDesignTokens.Colors.primaryText)
                    .focused($isFocused)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { onSubmit?() }
            } else {
                TextField(prompt ?? title, text: $text)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(isFocused ? Color.black : NuvioDesignTokens.Colors.primaryText)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { onSubmit?() }
            }
            if !text.isEmpty && isFocused {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(minHeight: 60)
        .background(
            isFocused ? Color.white : NuvioDesignTokens.Colors.elevated,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.clear : NuvioDesignTokens.Colors.neutral700,
                    lineWidth: 1
                )
        )
        .scaleEffect(reduceMotion ? 1 : (isFocused ? 1.03 : 1))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
