import Foundation
import SwiftUI
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

@MainActor
final class WatchAppointmentsViewModel: ObservableObject {
    @Published var appointments: [WatchAppointment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var lastRefresh: Date? = nil
    
    var completedCount: Int {
        appointments.filter { $0.isCompleted }.count
    }
    
    var totalCount: Int {
        appointments.count
    }
    
    /// Finds the currently active treatment (not completed, closest to current time).
    var activeAppointment: WatchAppointment? {
        let activeList = appointments.filter { !$0.isCompleted && !$0.isCancelled }
        guard !activeList.isEmpty else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMin = calendar.component(.minute, from: now)
        let currentTotalMins = currentHour * 60 + currentMin
        
        // Find appointment that spans current time
        for apt in activeList {
            let startParts = apt.startTime.split(separator: ":").compactMap { Int($0) }
            if startParts.count == 2 {
                let startMins = startParts[0] * 60 + startParts[1]
                let endMins: Int
                if let end = apt.endTime, let endParts = Optional(end.split(separator: ":").compactMap { Int($0) }), endParts.count == 2 {
                    endMins = endParts[0] * 60 + endParts[1]
                } else {
                    endMins = startMins + 60
                }
                
                if currentTotalMins >= (startMins - 15) && currentTotalMins <= endMins {
                    return apt
                }
            }
        }
        
        // Default to first active appointment
        return activeList.first
    }
    
    /// Finds the next upcoming appointment after the currently active one.
    var nextAppointment: WatchAppointment? {
        guard let active = activeAppointment else { return nil }
        let remaining = appointments.filter {
            !$0.isCompleted && !$0.isCancelled && $0.id != active.id
        }
        return remaining.first
    }
    
    var upcomingList: [WatchAppointment] {
        appointments.filter { !$0.isCompleted && !$0.isCancelled }
    }
    
    func loadAppointments() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await WatchAPIClient.shared.fetchTodayAppointments()
            self.appointments = fetched
            self.lastRefresh = Date()
            self.isLoading = false
            #if canImport(WatchKit)
            WKInterfaceDevice.current().play(.click)
            #endif
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func markCompleted(id: UUID) {
        if let index = appointments.firstIndex(where: { $0.id == id }) {
            appointments[index].status = "completed"
            #if canImport(WatchKit)
            WKInterfaceDevice.current().play(.success)
            #endif
        }
    }
}
