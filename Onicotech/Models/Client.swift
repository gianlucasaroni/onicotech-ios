import Foundation

struct Client: Codable, Identifiable, Hashable {
    var id: UUID?
    var firstName: String
    var lastName: String
    var phone: String?
    var email: String?
    var notes: String?

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
