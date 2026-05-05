import SwiftUI

@main
struct EnglishPaperReaderApp: App {
    @StateObject private var appContext = AppContext.bootstrap()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appContext)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            AppCommands()
        }
    }
}
