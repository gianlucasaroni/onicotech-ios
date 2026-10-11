import Foundation

struct Client: Codable, Identifiable, Hashable {
    var id: UUID?
    var firstName: String
    var lastName: String
    var phone: String?
    var email: String?
    var notes: String?
    var nailType: String?
    var allergies: String?
    var preferredShape: String?
    var technicalNotes: String?
    var customerTag: String?
    var promotionIds: [UUID] = []

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct ClientRecall: Codable, Identifiable, Hashable {
    var id: UUID { client.id ?? UUID() }
    var client: Client
    var lastAppointmentId: String
    var lastAppointmentDate: String
    var daysSinceLastAppointment: Int
    var weeksSinceLastAppointment: Int
    var lastServices: [String]
    var salonId: UUID?
    var salonName: String?
}
