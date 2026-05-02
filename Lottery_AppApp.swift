import SwiftUI
import SwiftData

@main
struct Lottery_AppApp: App {
    @State private var navigationPath = NavigationPath()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                ContentView(navigationPath: $navigationPath)
                    .preferredColorScheme(.light)
            }
        }
        .modelContainer(for: [LotteryDraw.self, ScannedTicket.self])
    }
}
