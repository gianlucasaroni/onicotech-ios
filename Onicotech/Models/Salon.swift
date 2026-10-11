import Foundation

struct Salon: Codable, Identifiable, Hashable, Equatable {
    var id: UUID
    var name: String
    var address: String?
    var city: String?
    var postalCode: String?
    var phone: String?
    var email: String?
    var notes: String?
    var isDefault: Bool
    var active: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    var fullAddress: String {
        var parts: [String] = []
        if let address, !address.isEmpty { parts.append(address) }
        if let city, !city.isEmpty { parts.append(city) }
        if let postalCode, !postalCode.isEmpty { parts.append(postalCode) }
        return parts.joined(separator: ", ")
    }
}

struct CreateSalonRequest: Codable {
    var name: String
    var address: String?
    var city: String?
    var postalCode: String?
    var phone: String?
    var email: String?
    var notes: String?
    var isDefault: Bool?
}

struct UpdateSalonRequest: Codable {
    var name: String
    var address: String?
    var city: String?
    var postalCode: String?
    var phone: String?
    var email: String?
    var notes: String?
    var isDefault: Bool?
    var active: Bool?
}

struct SalonServiceItem: Codable, Identifiable {
    var id: UUID { serviceId }
    var salonId: UUID
    var serviceId: UUID
    var service: Service?
    var priceOverride: Int? // In cents; if nil, uses service.price
    var active: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    func effectivePrice(basePrice: Int) -> Int {
        return priceOverride ?? basePrice
    }
    
    func formattedPrice(basePrice: Int) -> String {
        let cents = effectivePrice(basePrice: basePrice)
        return String(format: "€%.2f", Double(cents) / 100.0)
    }
}

struct SalonServiceUpdateDTO: Codable {
    var serviceId: UUID
    var priceOverride: Int?
    var active: Bool
}

struct UpdateSalonServicesRequest: Codable {
    var services: [SalonServiceUpdateDTO]
}

struct BusinessHourItem: Codable, Identifiable {
    var id: UUID?
    var salonId: UUID?
    var dayOfWeek: Int // 0 = Sunday, 1 = Monday, etc.
    var isOpen: Bool
    var startTime: String
    var endTime: String
    var breakStart: String?
    var breakEnd: String?
    
    var dayName: String {
        switch dayOfWeek {
        case 1: return "Lunedì"
        case 2: return "Martedì"
        case 3: return "Mercoledì"
        case 4: return "Giovedì"
        case 5: return "Venerdì"
        case 6: return "Sabato"
        case 0, 7: return "Domenica"
        default: return "Giorno \(dayOfWeek)"
        }
    }
}

struct UpdateBusinessHoursRequest: Codable {
    var hours: [BusinessHourItem]
}
