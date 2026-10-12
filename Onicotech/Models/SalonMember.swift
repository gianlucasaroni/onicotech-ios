import Foundation

public struct SalonMember: Codable, Identifiable, Hashable {
    public var id: UUID
    public var salonId: UUID
    public var userId: UUID?
    public var role: String // "owner" or "staff"
    public var isPractitioner: Bool
    public var displayName: String
    public var color: String?
    public var active: Bool
    public var serviceCommissionRate: Int?
    public var productCommissionRate: Int?
    public var createdAt: Date?
    
    public init(
        id: UUID,
        salonId: UUID,
        userId: UUID? = nil,
        role: String = "owner",
        isPractitioner: Bool = true,
        displayName: String,
        color: String? = nil,
        active: Bool = true,
        serviceCommissionRate: Int? = 0,
        productCommissionRate: Int? = 0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.salonId = salonId
        self.userId = userId
        self.role = role
        self.isPractitioner = isPractitioner
        self.displayName = displayName
        self.color = color
        self.active = active
        self.serviceCommissionRate = serviceCommissionRate
        self.productCommissionRate = productCommissionRate
        self.createdAt = createdAt
    }
    
    public var isOwner: Bool {
        role == "owner"
    }
}
