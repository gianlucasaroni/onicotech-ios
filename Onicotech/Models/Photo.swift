import Foundation

struct Photo: Codable, Identifiable, Hashable {
    let id: UUID
    let appointmentId: UUID
    let url: String
    let thumbnailUrl: String?
    let type: String // "before", "after", "other"
    let createdAt: Date
}
