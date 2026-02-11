import Foundation

struct APIResponse<T: Codable>: Codable {
    let data: T?
    let message: String?
}
