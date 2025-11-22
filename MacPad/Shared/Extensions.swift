import SwiftUI
import Foundation

extension Text {
    func sfDisplay(size: CGFloat = Constants.fontSize) -> Text {
        font(.system(size: size, design: .default))
    }
    
    func sfMono(size: CGFloat = Constants.fontSize) -> Text {
        font(.system(size: size, design: .monospaced))
    }
}

extension View {
    func paddingVertical(_ value: CGFloat) -> some View {
        padding(.vertical, value)
    }
    
    func paddingHorizontal(_ value: CGFloat) -> some View {
        padding(.horizontal, value)
    }
}

// App-wide notifications
extension Notification.Name {
    static let mpOpenFiles = Notification.Name("mpOpenFiles")
    static let mpQuickOpen = Notification.Name("mpQuickOpen")
    static let mpGoToLine = Notification.Name("mpGoToLine")
    static let mpScrollToLine = Notification.Name("mpScrollToLine")
}