import SwiftUI

/// PIN boxes (Android `ProfilePinBoxes`: four 118pt squares, 14pt gap) plus a
/// numeric focus grid for the Siri Remote. Android collects PIN digits from
/// the remote's number keys into a hidden text field; tvOS has no digit
/// keys, so the pad is the native equivalent (the brief specifies a numeric
/// focus grid).
struct ProfilePinBoxesView: View {
    let filledCount: Int
    let isError: Bool
    let shakeTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let boxSize: CGFloat = 118
    private let boxGap: CGFloat = 14

    var body: some View {
        HStack(spacing: boxGap) {
            ForEach(0..<ProfilePinEntry.length, id: \.self) { index in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fillColor(index))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(borderColor(index), lineWidth: borderWidth(index))
                    )
                    .frame(width: boxSize, height: boxSize)
            }
        }
        .modifier(ProfilePinShakeEffect(trigger: shakeTrigger, enabled: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filledCount) of \(ProfilePinEntry.length) digits entered")
    }

    private func isFilled(_ index: Int) -> Bool { index < filledCount }

    private func fillColor(_ index: Int) -> Color {
        if isError { return NuvioDesignTokens.Colors.error.opacity(isFilled(index) ? 0.42 : 0.16) }
        return isFilled(index) ? Color.white.opacity(0.2) : Color.white.opacity(0.07)
    }

    private func borderColor(_ index: Int) -> Color {
        if isError { return NuvioDesignTokens.Colors.error.opacity(0.8) }
        return isFilled(index) ? Color.white.opacity(0.65) : NuvioDesignTokens.Colors.neutral600
    }

    private func borderWidth(_ index: Int) -> CGFloat {
        isFilled(index) ? NuvioDesignTokens.Strokes.medium : NuvioDesignTokens.Strokes.hairline
    }
}

/// Android shake: -22, 18, -14, 10, -6, 0 over ~42ms steps. Reduced motion
/// disables the shake entirely.
struct ProfilePinShakeEffect: ViewModifier {
    let trigger: Int
    let enabled: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _ in
                guard enabled else { return }
                shake()
            }
    }

    private func shake() {
        let offsets: [CGFloat] = [-22, 18, -14, 10, -6, 0]
        offset = 0
        for (index, value) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.042) {
                withAnimation(.linear(duration: 0.042)) { offset = value }
            }
        }
    }
}

/// 3x4 numeric pad driven by native focus (1-9, delete, 0, cancel).
struct ProfilePinPadView: View {
    let filledCount: Int
    let isWorking: Bool
    var onDigit: (Int) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    private enum PadKey: Hashable {
        case digit(Int)
        case delete
        case cancel
    }

    @FocusState private var focusedKey: PadKey?

    private let columns = [
        GridItem(.fixed(96), spacing: 14),
        GridItem(.fixed(96), spacing: 14),
        GridItem(.fixed(96), spacing: 14)
    ]

    private let layout: [[PadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.delete, .digit(0), .cancel]
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(layout, id: \.self) { row in
                ForEach(row, id: \.self) { key in
                    padButton(for: key)
                }
            }
        }
        .defaultFocus($focusedKey, .digit(5))
    }

    @ViewBuilder
    private func padButton(for key: PadKey) -> some View {
        let shape = Circle()
        Button {
            guard !isWorking else { return }
            switch key {
            case .digit(let digit): onDigit(digit)
            case .delete: onDelete()
            case .cancel: onCancel()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: NuvioDesignTokens.Strokes.hairline))
                padLabel(for: key)
            }
            .frame(width: 96, height: 96)
        }
        .buttonStyle(PinPadButtonStyle(shape: shape))
        .focused($focusedKey, equals: key)
        .disabled(isWorking)
        .opacity(isWorking ? NuvioDesignTokens.Effects.disabledOpacity : 1)
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    @ViewBuilder
    private func padLabel(for key: PadKey) -> some View {
        switch key {
        case .digit(let digit):
            Text("\(digit)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.white)
        case .delete:
            Image(systemName: "delete.left")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        case .cancel:
            Text("Back")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private func accessibilityLabel(for key: PadKey) -> String {
        switch key {
        case .digit(let digit): return "\(digit)"
        case .delete: return "Delete digit"
        case .cancel: return "Cancel PIN entry"
        }
    }
}

private struct PinPadButtonStyle: ButtonStyle {
    let shape: Circle

    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle().fill(isFocused ? Color.white.opacity(0.14) : Color.clear)
            )
            .overlay(
                Circle().strokeBorder(
                    isFocused ? NuvioDesignTokens.Colors.defaultFocus : .clear,
                    lineWidth: NuvioDesignTokens.Strokes.focus
                )
            )
            .scaleEffect(isFocused ? NuvioDesignTokens.Focus.scale : 1)
            .animation(NuvioMotion.animation(for: .focus, reduceMotion: false), value: isFocused)
    }
}
