import SwiftUI

/// Card-like labels own their visuals while tvOS manages focus routing.
struct NuvioBareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// Shared actions use the system tvOS button styles. Focus, elevation, scale,
/// contrast, and press feedback are owned by tvOS.
struct NuvioButton: View {
    let title: String
    let symbol: String
    let focused: Bool
    var prominent = false
    var destructive = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Group {
            if destructive {
                Button(role: .destructive, action: action) {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if prominent {
                Button(action: action) {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .disabled(disabled)
    }
}
