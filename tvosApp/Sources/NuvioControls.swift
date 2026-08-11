import SwiftUI

struct NuvioBareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct NuvioFocusBorder: View {
    let focused: Bool
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(focused ? NuvioTheme.accent : Color.white.opacity(0.10), lineWidth: focused ? 4 : 1)
            .shadow(color: focused ? NuvioTheme.accent.opacity(0.65) : .clear, radius: 12)
    }
}

struct NuvioButton: View {
    let title: String
    let symbol: String
    let focused: Bool
    var prominent = false
    var destructive = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.white.opacity(disabled ? 0.45 : 1))
                .padding(.horizontal, 22)
                .frame(minHeight: 60)
                .frame(maxWidth: .infinity)
                .background(background, in: RoundedRectangle(cornerRadius: 15))
                .overlay(NuvioFocusBorder(focused: focused, cornerRadius: 15))
                .scaleEffect(focused ? 1.035 : 1)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(disabled)
        .animation(.easeOut(duration: 0.14), value: focused)
    }

    private var background: Color {
        if destructive { return Color.red.opacity(focused ? 0.70 : 0.38) }
        if prominent { return NuvioTheme.accent.opacity(focused ? 0.95 : 0.70) }
        return focused ? NuvioTheme.accent.opacity(0.55) : NuvioTheme.panelFocused
    }
}
