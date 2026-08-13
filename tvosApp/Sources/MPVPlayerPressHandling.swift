import UIKit

extension MPVPlayerController {
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let menuPresses = presses.filter { PlayerPressRouter.isMenu($0.type) }
        let handledMenu = !menuPresses.isEmpty && (session.onMenuPress?() ?? false)
        if handledMenu {
            consumedMenuPresses.formUnion(menuPresses.map(ObjectIdentifier.init))
        }
        let forwarded = handledMenu ? presses.subtracting(menuPresses) : presses
        guard !forwarded.isEmpty else { return }
        if forwarded.contains(where: { PlayerPressRouter.wakesControls($0.type) }) {
            session.onControlPress?()
        }
        super.pressesBegan(forwarded, with: event)
    }

    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let forwarded = excludingConsumedMenuPresses(from: presses)
        if !forwarded.isEmpty { super.pressesChanged(forwarded, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let forwarded = excludingConsumedMenuPresses(from: presses)
        removeConsumedMenuPresses(in: presses)
        if !forwarded.isEmpty { super.pressesEnded(forwarded, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let forwarded = excludingConsumedMenuPresses(from: presses)
        removeConsumedMenuPresses(in: presses)
        if !forwarded.isEmpty { super.pressesCancelled(forwarded, with: event) }
    }

    private func excludingConsumedMenuPresses(from presses: Set<UIPress>) -> Set<UIPress> {
        presses.filter { !consumedMenuPresses.contains(ObjectIdentifier($0)) }
    }

    private func removeConsumedMenuPresses(in presses: Set<UIPress>) {
        consumedMenuPresses.subtract(presses.map(ObjectIdentifier.init))
    }
}
