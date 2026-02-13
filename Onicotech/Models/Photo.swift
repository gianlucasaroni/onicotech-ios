import Foundation

struct Photo: Codable, Identifiable, Hashable {
    let id: UUID
    let appointmentId: UUID
    let type: String // "before", "after", "other"
    let createdAt: Date
    
    var fullThumbnailUrl: String {
        return "\(APIClient.baseServerURL)/photos/\(id)/thumbnail"
    }
    
    var fullOriginalUrl: String {
        return "\(APIClient.baseServerURL)/photos/\(id)/view"
    }
}
