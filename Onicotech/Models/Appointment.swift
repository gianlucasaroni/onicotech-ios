import Foundation

enum AppointmentStatus: String, Codable, CaseIterable {
    case scheduled
    case cancelled
    case rescheduled
    
    var displayName: String {
        switch self {
        case .scheduled: return "Programmato"
        case .cancelled: return "Cancellato"
        case .rescheduled: return "Riprogrammato"
        }
    }
    
    var iconName: String {
        switch self {
        case .scheduled: return "calendar.badge.clock"
        case .cancelled: return "xmark.circle.fill"
        case .rescheduled: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .cancelled: return "red"
        case .rescheduled: return "orange"
        }
    }
}

struct Appointment: Codable, Identifiable {
    var id: UUID?
    var date: String           // "YYYY-MM-DD"
    var startTime: String      // "HH:MM"
    var endTime: String?       // "HH:MM"
    var clientId: UUID
    var client: Client?
    var services: [Service]?
    var serviceIds: [UUID]?
    var totalPrice: Int? // cents
    var notes: String?
    var status: AppointmentStatus?
    
    var formattedTotalPrice: String {
        let value = Double(totalPrice ?? 0) / 100.0
        return String(format: "€%.2f", value)
    }
    
    var timeRange: String {
        if let end = endTime {
            return "\(startTime) - \(end)"
        }
        return startTime
    }
}

struct CreateAppointmentRequest: Codable {
    var date: String
    var startTime: String
    var clientId: UUID
    var serviceIds: [UUID]
    var notes: String?
}

struct UpdateAppointmentRequest: Codable {
    var date: String
    var startTime: String
    var clientId: UUID
    var serviceIds: [UUID]
    var notes: String?
    var status: AppointmentStatus
}
