import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case decodingError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta del server non valida"
        case .serverError(let message):
            return message
        case .decodingError(let message):
            return "Errore nella lettura dei dati: \(message)"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        }
    }
}

// MARK: - Auth Models
struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct User: Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
}

// MARK: - API Client
@MainActor
final class APIClient {
    static let shared = APIClient()
    
    // MARK: - Change this to your backend URL
    //static let baseServerURL = "http://192.168.1.42:8282/api/v1"
    static let baseServerURL = "http://192.168.1.14:8282/api/v1"
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    // MARK: - Auth
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        return try await request(path: "/auth/login", method: "POST", body: body)
    }
    
    func register(firstName: String, lastName: String, email: String, password: String) async throws -> AuthResponse {
        let body = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "password": password
        ]
        return try await request(path: "/auth/register", method: "POST", body: body)
    }
    
    func getProfile() async throws -> User {
        let response: APIResponse<User> = try await request(path: "/me")
        guard let user = response.data else { throw APIError.invalidResponse }
        return user
    }
    
    // MARK: - Generic Request
    
    private func request<T: Codable>(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(APIClient.baseServerURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        if let queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Auth Token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body {
            urlRequest.httpBody = try encoder.encode(body)
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 204 {
            // No Content — return a placeholder for Void-like responses
            let emptyJSON = "{}".data(using: .utf8)!
            return try decoder.decode(T.self, from: emptyJSON)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
                throw APIError.serverError(errorResponse.message ?? "Errore sconosciuto")
            }
            throw APIError.serverError("Errore del server (codice \(httpResponse.statusCode))")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - No-response request (for DELETE)
    
    private func requestNoContent(
        path: String,
        method: String
    ) async throws {
        guard let url = URL(string: "\(APIClient.baseServerURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        
        // Add Auth Token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
                throw APIError.serverError(errorResponse.message ?? "Errore sconosciuto")
            }
            throw APIError.serverError("Errore del server (codice \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Clients
    
    func getClients() async throws -> [Client] {
        let response: APIResponse<[Client]> = try await request(path: "/clients")
        return response.data ?? []
    }
    
    func getClient(id: UUID) async throws -> Client {
        let response: APIResponse<Client> = try await request(path: "/clients/\(id)")
        guard let client = response.data else { throw APIError.invalidResponse }
        return client
    }
    
    func createClient(_ client: Client) async throws -> Client {
        let response: APIResponse<Client> = try await request(path: "/clients", method: "POST", body: client)
        guard let created = response.data else { throw APIError.invalidResponse }
        return created
    }
    
    func updateClient(id: UUID, _ client: Client) async throws -> Client {
        let response: APIResponse<Client> = try await request(path: "/clients/\(id)", method: "PUT", body: client)
        guard let updated = response.data else { throw APIError.invalidResponse }
        return updated
    }
    
    func deleteClient(id: UUID) async throws {
        try await requestNoContent(path: "/clients/\(id)", method: "DELETE")
    }
    
    func getClientAppointments(clientId: UUID) async throws -> [Appointment] {
        let response: APIResponse<[Appointment]> = try await request(path: "/clients/\(clientId)/appointments")
        return response.data ?? []
    }
    
    // MARK: - Services
    
    func getServices() async throws -> [Service] {
        let response: APIResponse<[Service]> = try await request(path: "/services")
        return response.data ?? []
    }
    
    func createService(_ service: Service) async throws -> Service {
        let response: APIResponse<Service> = try await request(path: "/services", method: "POST", body: service)
        guard let created = response.data else { throw APIError.invalidResponse }
        return created
    }
    
    func updateService(id: UUID, _ service: Service) async throws -> Service {
        let response: APIResponse<Service> = try await request(path: "/services/\(id)", method: "PUT", body: service)
        guard let updated = response.data else { throw APIError.invalidResponse }
        return updated
    }
    
    func deleteService(id: UUID) async throws {
        try await requestNoContent(path: "/services/\(id)", method: "DELETE")
    }
    
    // MARK: - Appointments
    
    func getAppointments(date: String? = nil) async throws -> [Appointment] {
        var queryItems: [URLQueryItem]? = nil
        if let date {
            queryItems = [URLQueryItem(name: "date", value: date)]
        }
        let response: APIResponse<[Appointment]> = try await request(path: "/appointments", queryItems: queryItems)
        return response.data ?? []
    }
    
    func getAppointment(id: UUID) async throws -> Appointment {
        let response: APIResponse<Appointment> = try await request(path: "/appointments/\(id)")
        guard let appointment = response.data else { throw APIError.invalidResponse }
        return appointment
    }
    
    func createAppointment(_ request: CreateAppointmentRequest) async throws -> Appointment {
        let response: APIResponse<Appointment> = try await self.request(path: "/appointments", method: "POST", body: request)
        guard let created = response.data else { throw APIError.invalidResponse }
        return created
    }
    
    func updateAppointment(id: UUID, _ request: UpdateAppointmentRequest) async throws -> Appointment {
        let response: APIResponse<Appointment> = try await self.request(path: "/appointments/\(id)", method: "PUT", body: request)
        guard let updated = response.data else { throw APIError.invalidResponse }
        return updated
    }
    
    func deleteAppointment(id: UUID) async throws {
        try await requestNoContent(path: "/appointments/\(id)", method: "DELETE")
    }
    
    // MARK: - Dashboard
    
    func getDashboard() async throws -> DashboardData {
        let response: APIResponse<DashboardData> = try await request(path: "/dashboard")
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func getAdvancedStats() async throws -> AdvancedStats {
        let response: APIResponse<AdvancedStats> = try await request(path: "/dashboard/stats")
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    // MARK: - System
    
    func invalidateCache() async throws {
        try await requestNoContent(path: "/cache/invalidate", method: "POST")
    }
    
    // MARK: - Photos
    
    func uploadPhoto(appointmentId: UUID, image: Data, type: String) async throws -> Photo {
        let url = URL(string: "\(APIClient.baseServerURL)/appointments/\(appointmentId)/photos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add Auth Token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // appointmentId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"appointmentId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(appointmentId.uuidString)\r\n".data(using: .utf8)!)
        
        // type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(type)\r\n".data(using: .utf8)!)
        
        // image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(image)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
                throw APIError.serverError(errorResponse.message ?? "Errore sconosciuto")
            }
            throw APIError.serverError("Upload fallito")
        }
        
        let apiResponse = try decoder.decode(APIResponse<Photo>.self, from: data)
        guard let photo = apiResponse.data else { throw APIError.invalidResponse }
        return photo
    }
    
    func deletePhoto(id: UUID) async throws {
        try await requestNoContent(path: "/photos/\(id)", method: "DELETE")
    }
    
    func getAppointmentPhotos(appointmentId: UUID) async throws -> [Photo] {
        let response: APIResponse<[Photo]> = try await request(path: "/appointments/\(appointmentId.uuidString)/photos")
        return response.data ?? []
    }
    
    func getClientPhotos(clientId: UUID) async throws -> [Photo] {
        let response: APIResponse<[Photo]> = try await request(path: "/clients/\(clientId.uuidString)/photos")
        return response.data ?? []
    }
}
