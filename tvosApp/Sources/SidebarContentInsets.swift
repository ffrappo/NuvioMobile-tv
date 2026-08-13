import SwiftUI

private struct SidebarContentInsets: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaPadding(.leading, 360)
    }
}

extension View {
    func sidebarContentInsets() -> some View {
        modifier(SidebarContentInsets())
    }
}
