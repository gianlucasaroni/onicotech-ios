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
    var isPhoneMasked: Bool?
    var birthDay: Int?
    var birthMonth: Int?
    var birthYear: Int?
    var birthDate: String?
    var promotionIds: [UUID] = []

    init(
        id: UUID? = nil,
        firstName: String,
        lastName: String,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        nailType: String? = nil,
        allergies: String? = nil,
        preferredShape: String? = nil,
        technicalNotes: String? = nil,
        customerTag: String? = nil,
        isPhoneMasked: Bool? = nil,
        birthDay: Int? = nil,
        birthMonth: Int? = nil,
        birthYear: Int? = nil,
        birthDate: String? = nil,
        promotionIds: [UUID] = []
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email
        self.notes = notes
        self.nailType = nailType
        self.allergies = allergies
        self.preferredShape = preferredShape
        self.technicalNotes = technicalNotes
        self.customerTag = customerTag
        self.isPhoneMasked = isPhoneMasked
        self.birthDay = birthDay
        self.birthMonth = birthMonth
        self.birthYear = birthYear
        self.birthDate = birthDate
        self.promotionIds = promotionIds
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var formattedBirthDate: String? {
        if let birthDate = birthDate, !birthDate.isEmpty {
            return birthDate
        }
        guard let day = birthDay, let month = birthMonth, day >= 1 && day <= 31 && month >= 1 && month <= 12 else {
            return nil
        }
        let months = [
            "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
            "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"
        ]
        let monthName = months[month - 1]
        if let year = birthYear, year > 0 {
            return "\(day) \(monthName) \(year)"
        }
        return "\(day) \(monthName)"
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
