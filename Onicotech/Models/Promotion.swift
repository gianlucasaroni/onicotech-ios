import Foundation

struct Promotion: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID?
    var salonId: UUID?
    var salon: Salon?
    var name: String
    var description: String?
    var discountPercent: Double
    var startDate: Date?
    var endDate: Date?
    var active: Bool
    var clientIds: [UUID]?
    var createdAt: Date?
    var updatedAt: Date?
    
    init(
        id: UUID,
        userId: UUID? = nil,
        salonId: UUID? = nil,
        salon: Salon? = nil,
        name: String,
        description: String? = nil,
        discountPercent: Double,
        startDate: Date? = nil,
        endDate: Date? = nil,
        active: Bool = true,
        clientIds: [UUID]? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
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

    enum CodingKeys: String, CodingKey {
        case id, userId, salonId, salon, name, description, discountPercent, startDate, endDate, active, clientIds, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        salonId = try container.decodeIfPresent(UUID.self, forKey: .salonId)
        salon = try container.decodeIfPresent(Salon.self, forKey: .salon)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        discountPercent = try container.decode(Double.self, forKey: .discountPercent)
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        clientIds = try container.decodeIfPresent([UUID].self, forKey: .clientIds)

        let decodeFlexibleDate: (CodingKeys) -> Date? = { key in
            if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
                return date
            }
            if let str = try? container.decodeIfPresent(String.self, forKey: key) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let d = formatter.date(from: str) {
                    return d
                }
                let isoFormatter = ISO8601DateFormatter()
                return isoFormatter.date(from: str)
            }
            return nil
        }

        startDate = decodeFlexibleDate(.startDate)
        endDate = decodeFlexibleDate(.endDate)
        createdAt = decodeFlexibleDate(.createdAt)
        updatedAt = decodeFlexibleDate(.updatedAt)
    }
    
    var isValid: Bool {
        guard active else { return false }
        let now = Date()
        if let start = startDate, now < start { return false }
        if let end = endDate, now > end { return false }
        return true
    }
}
