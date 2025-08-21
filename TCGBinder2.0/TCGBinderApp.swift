import SwiftUI

@main
struct TCGBinderApp: App {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appColorScheme.colorScheme)
        }
    }
}