import Foundation

struct DashboardData: Codable {
    var nextAppointments: [Appointment]?
    var totalClients: Int
    var newClientsThisMonth: Int
    var monthlyEarnings: Int
    
    enum CodingKeys: String, CodingKey {
        case nextAppointments
        case totalClients
        case newClientsThisMonth
        case monthlyEarnings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.nextAppointments = try container.decodeIfPresent([Appointment].self, forKey: .nextAppointments) ?? []
        self.totalClients = try container.decodeIfPresent(Int.self, forKey: .totalClients) ?? 0
        self.newClientsThisMonth = try container.decodeIfPresent(Int.self, forKey: .newClientsThisMonth) ?? 0
        self.monthlyEarnings = try container.decodeIfPresent(Int.self, forKey: .monthlyEarnings) ?? 0
    }
}
