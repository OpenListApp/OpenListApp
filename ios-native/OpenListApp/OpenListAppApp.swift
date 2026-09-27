import SwiftUI

@main
struct OpenListApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            root
                .environment(appState)
                .tint(.blue)
                .animation(.spring(duration: 0.4), value: appState.isSignedIn)
        }
    }

    @ViewBuilder
    private var root: some View {
        if appState.isSignedIn {
            RootTabView()
        } else {
            LoginView()
        }
    }
}
