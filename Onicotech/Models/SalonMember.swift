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
    public var canViewAllClients: Bool?
    public var maskClientPhone: Bool?
    public var serviceCommissionRate: Int?
    public var productCommissionRate: Int?
    public var calendarFeedToken: String?
    public var calendarFeedUrl: String?
    public var calendarWebcalUrl: String?
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
        canViewAllClients: Bool? = true,
        maskClientPhone: Bool? = false,
        serviceCommissionRate: Int? = 0,
        productCommissionRate: Int? = 0,
        calendarFeedToken: String? = nil,
        calendarFeedUrl: String? = nil,
        calendarWebcalUrl: String? = nil,
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
        self.canViewAllClients = canViewAllClients
        self.maskClientPhone = maskClientPhone
        self.serviceCommissionRate = serviceCommissionRate
        self.productCommissionRate = productCommissionRate
        self.calendarFeedToken = calendarFeedToken
        self.calendarFeedUrl = calendarFeedUrl
        self.calendarWebcalUrl = calendarWebcalUrl
        self.createdAt = createdAt
    }
    
    public var isOwner: Bool {
        role == "owner"
    }

    public func calendarFeedURL(baseURL: String) -> URL? {
        guard let token = calendarFeedToken, !token.isEmpty else { return nil }
        let cleanBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return URL(string: "\(cleanBase)/public/calendar/feed/\(token).ics")
    }

    public func calendarWebcalURL(baseURL: String) -> URL? {
        guard let token = calendarFeedToken, !token.isEmpty else { return nil }
        let cleanBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let webcalBase = cleanBase.replacingOccurrences(of: "https://", with: "webcal://")
            .replacingOccurrences(of: "http://", with: "webcal://")
        return URL(string: "\(webcalBase)/public/calendar/feed/\(token).ics")
    }

    public func googleCalendarSubscribeURL(baseURL: String) -> URL? {
        guard let httpURL = calendarFeedURL(baseURL: baseURL)?.absoluteString else { return nil }
        guard let encoded = httpURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://calendar.google.com/calendar/render?cid=\(encoded)")
    }
}
