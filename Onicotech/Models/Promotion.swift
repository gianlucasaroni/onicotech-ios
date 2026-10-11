import Foundation

struct Promotion: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    var salonId: UUID?
    var salon: Salon?
    var name: String
    var description: String?
    var discountPercent: Double
    var startDate: Date?
    var endDate: Date?
    var active: Bool
    var clientIds: [UUID]?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: UUID,
        userId: UUID,
        salonId: UUID? = nil,
        salon: Salon? = nil,
        name: String,
        description: String? = nil,
        discountPercent: Double,
        startDate: Date? = nil,
        endDate: Date? = nil,
        active: Bool = true,
        clientIds: [UUID]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.salonId = salonId
        self.salon = salon
        self.name = name
        self.description = description
        self.discountPercent = discountPercent
        self.startDate = startDate
        self.endDate = endDate
        self.active = active
        self.clientIds = clientIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isValid: Bool {
        guard active else { return false }
        let now = Date()
        if let start = startDate, now < start { return false }
        if let end = endDate, now > end { return false }
        return true
    }
}
