import Foundation

struct Service: Codable, Identifiable {
    var id: UUID?
    var name: String
    var description: String?
    var price: Int // cents
    var duration: Int // minutes
    var active: Bool

    var formattedPrice: String {
        let value = Double(price) / 100.0
        return String(format: "€%.2f", value)
    }

    var formattedDuration: String {
        if duration >= 60 {
            let hours = duration / 60
            let mins = duration % 60
            return mins > 0 ? "\(hours)h \(mins)min" : "\(hours)h"
        }
        return "\(duration) min"
    }
}
