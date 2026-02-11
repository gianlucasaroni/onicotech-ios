import Foundation
import Observation
internal import EventKit
import SwiftUI
import Combine

@Observable
class AppointmentViewModel {
    var appointments: [Appointment] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false
    var selectedDate: Date = .now
    
    private let api = APIClient.shared
    
    var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
    
    func loadAppointments() async {
        isLoading = true
        errorMessage = nil
        do {
            appointments = try await api.getAppointments(date: selectedDateString)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func createAppointment(request: CreateAppointmentRequest) async -> Bool {
        do {
            let created = try await api.createAppointment(request)
            let client = try? await api.getClient(id: request.clientId)
            var appointmentWithClient = created
            appointmentWithClient.client = client
            
            appointments.append(appointmentWithClient)
            appointments.sort { $0.startTime < $1.startTime }
            
            // Sync
            CalendarManager.shared.syncAppointment(appointmentWithClient)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func updateAppointment(id: UUID, request: UpdateAppointmentRequest) async -> Bool {
        do {
            let updated = try await api.updateAppointment(id: id, request)
            if let index = appointments.firstIndex(where: { $0.id == id }) {
                var updatedWithClient = updated
                updatedWithClient.client = appointments[index].client // Preserve client info
                appointments[index] = updatedWithClient
                
                // Sync
                CalendarManager.shared.syncAppointment(updatedWithClient)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func deleteAppointment(id: UUID) async -> Bool {
        do {
            try await api.deleteAppointment(id: id)
            appointments.removeAll { $0.id == id }
            
            // Sync
            CalendarManager.shared.deleteEvent(for: id)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func cancelAppointment(id: UUID) async -> Bool {
        guard let index = appointments.firstIndex(where: { $0.id == id }) else { return false }
        let current = appointments[index]
        
        // Ensure we have service IDs
        // Services are populated. If not, we might fail validation.
        // Assuming services are loaded.
        let serviceIds = current.services?.compactMap { $0.id } ?? []
        
        let request = UpdateAppointmentRequest(
            date: current.date,
            startTime: current.startTime,
            clientId: current.clientId,
            serviceIds: serviceIds,
            notes: current.notes,
            status: .cancelled
        )
        
        // Reuse updateAppointment which handles API and Sync
        return await updateAppointment(id: id, request: request)
    }
}

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    @Published var predefinedCalendars: [EKCalendar] = []
    
    // UserDefaults keys
    private let calendarIdKey = "selectedCalendarId"
    private let syncEnabledKey = "isCalendarSyncEnabled"
    
    // Sync settings
    @AppStorage("isCalendarSyncEnabled") var isSyncEnabled: Bool = false
    @AppStorage("selectedCalendarId") var selectedCalendarId: String = ""
    
    private init() {}
    
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            if granted {
                await fetchCalendars()
            }
            return granted
        } catch {
            print("Error requesting calendar access: \(error)")
            return false
        }
    }
    
    @MainActor
    func fetchCalendars() {
        let calendars = eventStore.calendars(for: .event)
        // Filter for writable calendars
        self.predefinedCalendars = calendars.filter { $0.allowsContentModifications }
        
        // If a calendar was selected but no longer exists, reset
        if !selectedCalendarId.isEmpty && !self.predefinedCalendars.contains(where: { $0.calendarIdentifier == selectedCalendarId }) {
            selectedCalendarId = ""
        }
        
        // Auto-select first if none selected
        if selectedCalendarId.isEmpty, let first = self.predefinedCalendars.first {
            selectedCalendarId = first.calendarIdentifier
        }
    }
    
    // MARK: - Event Management
    
    func syncAppointment(_ appointment: Appointment) {
        guard isSyncEnabled, !selectedCalendarId.isEmpty else { return }
        
        guard let calendar = eventStore.calendar(withIdentifier: selectedCalendarId) else { return }
        
        // Check if event already exists locally (mapped)
        let eventIdKey = "appt_event_\(appointment.id!.uuidString)"
        let existingEventId = UserDefaults.standard.string(forKey: eventIdKey)
        
        let event: EKEvent
        if let existingEventId, let existing = eventStore.event(withIdentifier: existingEventId) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
        }
        
        // Update event details
        let clientName = "\(appointment.client?.firstName ?? "Cliente") \(appointment.client?.lastName ?? "")"
        event.title = "Appt: \(clientName)"
        
        // Build description
        var description = ""
        var totalDuration = 0
        var totalPrice = 0.0
        
        if let services = appointment.services {
            description += "Servizi:\n"
            for service in services {
                let priceDecimal = Double(service.price) / 100.0
                description += "- \(service.name) (\(String(format: "%.2f", priceDecimal))€)\n"
                totalDuration += service.duration
                totalPrice += priceDecimal
            }
            description += "\n"
        }
        
        description += "Totale: \(String(format: "%.2f", totalPrice))€\n"
        
        if let notes = appointment.notes, !notes.isEmpty {
            description += "\nNote:\n\(notes)"
        }
        
        event.notes = description
        event.calendar = calendar
        
        // Parse date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let startDate = formatter.date(from: "\(appointment.date) \(appointment.startTime)") {
            event.startDate = startDate
            
            // Default to 60 min if 0/undefined
            if totalDuration == 0 { totalDuration = 60 }
            
            event.endDate = startDate.addingTimeInterval(TimeInterval(totalDuration * 60))
        } else {
            return // Invalid date
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            UserDefaults.standard.set(event.eventIdentifier, forKey: eventIdKey)
        } catch {
            print("Failed to save event: \(error)")
        }
    }
    
    func deleteEvent(for appointmentId: UUID) {
        let eventIdKey = "appt_event_\(appointmentId.uuidString)"
        guard let existingEventId = UserDefaults.standard.string(forKey: eventIdKey) else { return }
        
        if let event = eventStore.event(withIdentifier: existingEventId) {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                print("Failed to delete event: \(error)")
            }
        }
        UserDefaults.standard.removeObject(forKey: eventIdKey)
    }
}
