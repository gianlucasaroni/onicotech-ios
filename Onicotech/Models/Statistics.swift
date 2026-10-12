import Foundation

struct AdvancedStats: Codable {
    let topSpenders: [TopSpender]?
    let topServices: [TopService]?
    let monthlyRevenue: [MonthlyRevenue]?
    let flopSpenders: [TopSpender]?
    let flopServices: [TopService]?
    let unreliableClients: [UnreliableClient]?
    
    var isEmpty: Bool {
        (topSpenders?.isEmpty ?? true) &&
        (topServices?.isEmpty ?? true) &&
        (monthlyRevenue?.isEmpty ?? true) &&
        (flopSpenders?.isEmpty ?? true) &&
        (flopServices?.isEmpty ?? true) &&
        (unreliableClients?.isEmpty ?? true)
    }
}

struct TopSpender: Codable, Identifiable {
    let id: UUID?
    let firstName: String
    let lastName: String
    let totalSpend: Double
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var formattedSpend: String {
        let value = totalSpend / 100.0
        return String(format: "€%.2f", value)
    }
}

struct TopService: Codable, Identifiable {
    let id: UUID?
    let name: String
    let usageCount: Int
}

struct UnreliableClient: Codable, Identifiable {
    let id: UUID?
    let firstName: String
    let lastName: String
    let count: Int
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct MonthlyRevenue: Codable, Identifiable {
    let month: String // "YYYY-MM"
    let revenue: Double
    
    var id: String { month }
    
    var formattedRevenue: String {
        return String(format: "€%.0f", revenue / 100.0)
    }
    
    // Helper to get Date object
    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: month)
    }
    
    var monthName: String {
        guard let d = date else { return month }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: d)
    }
}

public struct StaffPerformance: Codable, Identifiable, Hashable {
    public var id: UUID { staffMemberId }
    public let staffMemberId: UUID
    public let displayName: String
    public let color: String?
    public let role: String
    public let serviceCommissionRate: Int
    public let productCommissionRate: Int
    public let completedTreatments: Int
    public let serviceRevenue: Int64
    public let serviceCommissionEarned: Int64
    public let retailProductsSold: Int
    public let retailRevenue: Int64
    public let productCommissionEarned: Int64
    public let totalCommissionEarned: Int64
    public let salonNetRevenue: Int64
    
    public var formattedServiceRevenue: String {
        String(format: "€%.2f", Double(serviceRevenue) / 100.0)
    }
    
    public var formattedTotalEarned: String {
        String(format: "€%.2f", Double(totalCommissionEarned) / 100.0)
    }
    
    public var formattedNetRevenue: String {
        String(format: "€%.2f", Double(salonNetRevenue) / 100.0)
    }
}

public struct StaffReportData: Codable {
    public let startDate: String
    public let endDate: String
    public let staff: [StaffPerformance]
    public let totalSalonServiceRevenue: Int64
    public let totalSalonProductRevenue: Int64
    public let totalSalonRevenue: Int64
    public let totalStaffCommissions: Int64
    public let totalSalonNet: Int64
}
