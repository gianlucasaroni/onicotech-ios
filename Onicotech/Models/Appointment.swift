import Foundation

enum AppointmentStatus: String, Codable, CaseIterable {
    case scheduled
    case pending
    case completed
    case cancelled
    case rescheduled
    case expired
    
    var displayName: String {
        switch self {
        case .scheduled: return "Programmato"
        case .pending: return "In Attesa"
        case .completed: return "Completato"
        case .cancelled: return "Cancellato"
        case .rescheduled: return "Riprogrammato"
        case .expired: return "Scaduto"
        }
    }
    
    var iconName: String {
        switch self {
        case .scheduled: return "calendar.badge.clock"
        case .pending: return "hourglass"
        case .completed: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        case .rescheduled: return "arrow.triangle.2.circlepath.circle.fill"
        case .expired: return "clock.badge.xmark"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .pending: return "orange"
        case .completed: return "green"
        case .cancelled: return "red"
        case .rescheduled: return "yellow"
        case .expired: return "gray"
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
    var salonId: UUID?
    var salon: Salon?
    var staffMemberId: UUID?
    var staffMember: SalonMember?
    var services: [Service]?
    var serviceIds: [UUID]?
    var products: [AppointmentProduct]?
    var totalPrice: Int? // cents
    var discountAmount: Int? // cents
    var finalPrice: Int? // cents
    var notes: String?
    var status: AppointmentStatus?
    var promotionId: UUID?
    var promotion: Promotion?
    
    var formattedTotalPrice: String {
        let value = Double(totalPrice ?? 0) / 100.0
        return String(format: "€%.2f", value)
    }

    var formattedDiscountAmount: String {
        let value = Double(discountAmount ?? 0) / 100.0
        return String(format: "-€%.2f", value)
    }

    var formattedFinalPrice: String {
        let value = Double(finalPrice ?? totalPrice ?? 0) / 100.0
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
    var salonId: UUID?
    var staffMemberId: UUID?
    var serviceIds: [UUID]
    var notes: String?
    var promotionId: UUID?
}

struct UpdateAppointmentRequest: Codable {
    var date: String
    var startTime: String
    var clientId: UUID
    var salonId: UUID?
    var staffMemberId: UUID?
    var serviceIds: [UUID]
    var notes: String?
    var promotionId: UUID?
    var status: AppointmentStatus
}

struct AppointmentProduct: Codable, Identifiable {
    var id: UUID?
    var appointmentId: UUID?
    var productId: UUID
    var product: Product?
    var quantity: Int
    var unitPrice: Int // cents
    
    var formattedUnitPrice: String {
        CurrencyFormatting.euros(fromCents: unitPrice)
    }
    
    var formattedSubtotal: String {
        CurrencyFormatting.euros(fromCents: unitPrice * quantity)
    }
}

