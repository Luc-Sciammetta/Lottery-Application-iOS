import SwiftUI
import SwiftData

@main
struct Lottery_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: LotteryDraw.self)
    }
}
