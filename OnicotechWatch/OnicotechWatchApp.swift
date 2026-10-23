import SwiftUI

@main
struct OnicotechWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var appointmentsVM = WatchAppointmentsViewModel()
    @StateObject private var timerManager = CuringTimerManager.shared
    
    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(sessionManager)
                .environmentObject(appointmentsVM)
                .environmentObject(timerManager)
        }
    }
}
