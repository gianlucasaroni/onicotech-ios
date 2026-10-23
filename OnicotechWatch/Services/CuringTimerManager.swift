import Foundation
import SwiftUI
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

@MainActor
final class CuringTimerManager: ObservableObject {
    static let shared = CuringTimerManager()
    
    @Published var totalSeconds: Int = 60
    @Published var remainingSeconds: Int = 0
    @Published var isRunning: Bool = false
    
    private var timerSubscription: AnyCancellable?
    
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
    
    var formattedRemainingTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
    
    func start(seconds: Int) {
        stop()
        self.totalSeconds = max(1, seconds)
        self.remainingSeconds = max(1, seconds)
        self.isRunning = true
        
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.start)
        #endif
        
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.timerFinished()
                }
            }
    }
    
    func pause() {
        isRunning = false
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    
    func resume() {
        guard remainingSeconds > 0 else { return }
        isRunning = true
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.timerFinished()
                }
            }
    }
    
    func stop() {
        isRunning = false
        remainingSeconds = 0
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    
    private func timerFinished() {
        stop()
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}
