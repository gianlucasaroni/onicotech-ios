import Foundation

struct Promotion: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var description: String?
    var discountPercent: Double
    var startDate: Date?
    var endDate: Date?
    var active: Bool
    var clientIds: [UUID]?
    let createdAt: Date
    let updatedAt: Date
    
    var isValid: Bool {
        guard active else { return false }
        let now = Date()
        if let start = startDate, now < start { return false }
        if let end = endDate, now > end { return false }
        return true
    }
}
