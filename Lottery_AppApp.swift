import SwiftUI
import SwiftData
import UserNotifications

@main
struct Lottery_AppApp: App {
    @State private var navigationPath = NavigationPath()
    
    init(){
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
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
