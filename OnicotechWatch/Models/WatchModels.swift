import Foundation

/// Lightweight appointment model optimized for Apple Watch display and memory constraints.
struct WatchAppointment: Identifiable, Codable, Hashable {
    let id: UUID
    let date: String           // "YYYY-MM-DD"
    let startTime: String      // "HH:MM"
    let endTime: String?       // "HH:MM"
    let clientName: String
    let clientPhone: String?
    let serviceName: String
    let priceCents: Int?
    let notes: String?
    let allergies: String?
    var status: String         // "scheduled", "pending", "completed", "cancelled"
    
    var isCompleted: Bool {
        status == "completed"
    }
    
    var isCancelled: Bool {
        status == "cancelled"
    }
    
    var isPending: Bool {
        status == "pending"
    }
    
    var hasAllergies: Bool {
        if let allergies, !allergies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }
    
    var timeRangeFormatted: String {
        if let endTime, !endTime.isEmpty {
            return "\(startTime) - \(endTime)"
        }
        return startTime
    }
}
