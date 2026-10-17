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
    
    var servicesTotal: Int {
        services?.reduce(0) { $0 + ($1.price) } ?? 0
    }

    var productsTotal: Int {
        products?.reduce(0) { $0 + ($1.unitPrice * $1.quantity) } ?? 0
    }

    var calculatedGrandTotal: Int {
        let serv = servicesTotal
        let prod = productsTotal
        let discount = discountAmount ?? 0
        let base = totalPrice ?? 0

        if prod > 0 && base == serv {
            return max(0, serv + prod - discount)
        }
        if let final = finalPrice, final > 0 {
            if prod > 0 && final == (serv - discount) {
                return max(0, final + prod)
            }
            return final
        }
        if base > 0 {
            return max(0, base - discount)
        }
        return max(0, serv + prod - discount)
    }

    var formattedTotalPrice: String {
        let serv = servicesTotal
        let prod = productsTotal
        let base = totalPrice ?? serv
        let full = (prod > 0 && base == serv) ? (serv + prod) : base
        return CurrencyFormatting.euros(fromCents: full)
    }

    var formattedDiscountAmount: String {
        let value = Double(discountAmount ?? 0) / 100.0
        return String(format: "-€%.2f", value)
    }

    var formattedFinalPrice: String {
        CurrencyFormatting.euros(fromCents: calculatedGrandTotal)
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
    var productName: String?
    var category: String?
    var product: Product?
    var quantity: Int
    var unitPrice: Int // cents
    var subtotal: Int?
    
    var displayName: String {
        if let name = productName, !name.isEmpty {
            return name
        }
        if let name = product?.name, !name.isEmpty {
            return name
        }
        return "Prodotto"
    }
    
    var displayCategory: String? {
        if let cat = category, !cat.isEmpty {
            return cat
        }
        return product?.category
    }
    
    var formattedUnitPrice: String {
        CurrencyFormatting.euros(fromCents: unitPrice)
    }
    
    var formattedSubtotal: String {
        if let sub = subtotal {
            return CurrencyFormatting.euros(fromCents: sub)
        }
        return CurrencyFormatting.euros(fromCents: unitPrice * quantity)
    }
}

