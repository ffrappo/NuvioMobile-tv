import UIKit

final class PlayerExitCoordinator {
    enum Action: Equatable {
        case closePanel
        case hideControls
        case leavePlayer
    }

    func action(panelPresented: Bool, controlsVisible: Bool) -> Action {
        if panelPresented { return .closePanel }
        if controlsVisible { return .hideControls }
        return .leavePlayer
    }
}

enum PlayerPressRouter {
    static func isMenu(_ type: UIPress.PressType) -> Bool {
        type == .menu
    }

    static func wakesControls(_ type: UIPress.PressType) -> Bool {
        switch type {
        case .upArrow, .downArrow, .leftArrow, .rightArrow, .select, .playPause:
            return true
        default:
            return false
        }
    }
}
