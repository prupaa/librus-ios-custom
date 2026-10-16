import SwiftUI

public struct CustomBackgroundModifier: ViewModifier {
    @ObservedObject var appState: AppState

    public func body(content: Content) -> some View {
        ZStack {
            if let bgData = appState.backgroundImageData,
               let uiImage = UIImage(data: bgData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: appState.backgroundBlurRadius)
                    .overlay(
                        Color.black.opacity(appState.backgroundDimOpacity)
                            .ignoresSafeArea()
                    )
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }

            content
        }
        .tint(appState.selectedTheme.color)
    }
}

public extension View {
    func customAppBackground(appState: AppState) -> some View {
        self.modifier(CustomBackgroundModifier(appState: appState))
    }
}
