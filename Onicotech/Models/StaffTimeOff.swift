import Foundation

public struct StaffTimeOff: Codable, Identifiable, Hashable {
    public let id: UUID
    public let salonId: UUID
    public let staffMemberId: UUID
    public let staffMember: SalonMember?
    public let startDate: String // YYYY-MM-DD
    public let endDate: String   // YYYY-MM-DD
    public let startTime: String? // HH:MM
    public let endTime: String?   // HH:MM
    public let isAllDay: Bool
    public let reason: String
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(
        id: UUID,
        salonId: UUID,
        staffMemberId: UUID,
        staffMember: SalonMember? = nil,
        startDate: String,
        endDate: String,
        startTime: String? = nil,
        endTime: String? = nil,
        isAllDay: Bool = true,
        reason: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.salonId = salonId
        self.staffMemberId = staffMemberId
        self.staffMember = staffMember
        self.startDate = startDate
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
