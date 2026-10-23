import Foundation

enum WatchAPIError: LocalizedError {
    case unauthenticated
    case invalidURL
    case serverError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .unauthenticated: return "Effettua il login dall'iPhone"
        case .invalidURL: return "URL non valido"
        case .serverError(let msg): return msg
        case .decodingError: return "Errore formato dati"
        }
    }
}

/// Lightweight API client for watchOS
@MainActor
final class WatchAPIClient {
    static let shared = WatchAPIClient()
    
    private let session = URLSession.shared
    
    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    func fetchTodayAppointments() async throws -> [WatchAppointment] {
        let sessionManager = WatchSessionManager.shared
        guard let token = sessionManager.authToken, !token.isEmpty else {
            throw WatchAPIError.unauthenticated
        }
        
        let todayString = dateFormatter.string(from: Date())
        var urlComponents = URLComponents(string: "\(sessionManager.serverUrl)/appointments")
        
        var queryItems = [URLQueryItem(name: "date", value: todayString)]
        if let salonId = sessionManager.salonId, !salonId.isEmpty, salonId != "all" {
            queryItems.append(URLQueryItem(name: "salonId", value: salonId))
        }
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw WatchAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchAPIError.serverError("Risposta server non valida")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WatchAPIError.serverError("Errore \(httpResponse.statusCode)")
        }
        
        struct RawApiResponse: Codable {
            let data: [RawAppointment]?
        }
        
        struct RawAppointment: Codable {
            let id: UUID?
            let date: String
            let startTime: String
            let endTime: String?
            let client: RawClient?
            let services: [RawService]?
            let totalPrice: Int?
            let finalPrice: Int?
            let notes: String?
            let status: String?
        }
        
        struct RawClient: Codable {
            let firstName: String
            let lastName: String
            let phone: String?
            let allergies: String?
        }
        
        struct RawService: Codable {
            let name: String
            let price: Int?
        }
        
        let decoded = try JSONDecoder().decode(RawApiResponse.self, from: data)
        let list = decoded.data ?? []
        
        return list.compactMap { raw in
            guard let id = raw.id else { return nil }
            let clientName: String
            if let c = raw.client {
                clientName = "\(c.firstName) \(c.lastName)".trimmingCharacters(in: .whitespaces)
            } else {
                clientName = "Cliente"
            }
            
            let serviceNames = raw.services?.map { $0.name }.joined(separator: ", ") ?? "Trattamento"
            
            return WatchAppointment(
                id: id,
                date: raw.date,
                startTime: raw.startTime,
                endTime: raw.endTime,
                clientName: clientName,
                clientPhone: raw.client?.phone,
                serviceName: serviceNames.isEmpty ? "Trattamento" : serviceNames,
                priceCents: raw.finalPrice ?? raw.totalPrice,
                notes: raw.notes,
                allergies: raw.client?.allergies,
                status: raw.status ?? "scheduled"
            )
        }.sorted { $0.startTime < $1.startTime }
    }
}
