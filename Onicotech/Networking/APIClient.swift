import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case decodingError(String)
    case networkError(String)
    case sessionExpired
    
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
        case .sessionExpired:
            return "Sessione scaduta, effettua nuovamente il login"
        }
    }
}

// MARK: - Auth Models
struct AuthResponse: Codable {
    let token: String
    let refreshToken: String
    let user: User
}

struct RefreshResponse: Codable {
    let token: String
    let refreshToken: String
}

struct User: Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    var role: String?
    
    var isOwner: Bool {
        role != "staff"
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

// MARK: - API Client
@MainActor
final class APIClient {
    static let shared = APIClient()
    
    // MARK: - Change this to your backend URL
    //static let baseServerURL = "http://192.168.1.166:8282/api/v1"
    static let baseServerURL = "http://192.168.1.14:8282/api/v1"
    //static let baseServerURL = "http://be-onicotech.casaperoni/api/v1"
    
    static var baseWebURL: String {
        if let url = URL(string: baseServerURL), let host = url.host {
            let scheme = url.scheme ?? "http"
            if host.contains("casaperoni") {
                return "\(scheme)://onicotech.casaperoni"
            } else if host == "127.0.0.1" || host.starts(with: "192.168.") || host == "localhost" {
                return "\(scheme)://\(host):4200"
            }
        }
        return "https://onicotech.it"
    }
    
    private var isRefreshing = false
    
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
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken() async throws {
        guard let refreshToken = UserDefaults.standard.string(forKey: StorageKeys.refreshToken) else {
            throw APIError.sessionExpired
        }
        
        guard let url = URL(string: "\(APIClient.baseServerURL)/auth/refresh") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode([StorageKeys.refreshToken: refreshToken])
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // Refresh failed — clear tokens and notify
            UserDefaults.standard.removeObject(forKey: StorageKeys.authToken)
            UserDefaults.standard.removeObject(forKey: StorageKeys.refreshToken)
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            throw APIError.sessionExpired
        }
        
        let refreshResponse = try decoder.decode(RefreshResponse.self, from: data)
        UserDefaults.standard.set(refreshResponse.token, forKey: StorageKeys.authToken)
        UserDefaults.standard.set(refreshResponse.refreshToken, forKey: StorageKeys.refreshToken)
    }
    
    // MARK: - Generic Request
    
    private func request<T: Codable>(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let result: T = try await performRequest(path: path, method: method, body: body, queryItems: queryItems)
        return result
    }
    
    private func performRequest<T: Codable>(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        isRetry: Bool = false
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
        if let token = UserDefaults.standard.string(forKey: StorageKeys.authToken) {
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
        
        // Handle 401: try to refresh token and retry once
        if httpResponse.statusCode == 401 && !isRetry {
            try await refreshAccessToken()
            return try await performRequest(path: path, method: method, body: body, queryItems: queryItems, isRetry: true)
        }
        
        if httpResponse.statusCode == 204 {
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
        method: String,
        isRetry: Bool = false
    ) async throws {
        guard let url = URL(string: "\(APIClient.baseServerURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        
        // Add Auth Token
        if let token = UserDefaults.standard.string(forKey: StorageKeys.authToken) {
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
        
        // Handle 401: try to refresh token and retry once
        if httpResponse.statusCode == 401 && !isRetry {
            try await refreshAccessToken()
            try await requestNoContent(path: path, method: method, isRetry: true)
            return
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
    
    func getRecallClients(days: Int = 21, salonId: UUID? = nil) async throws -> [ClientRecall] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "days", value: "\(days)")
        ]
        if let salonId = salonId {
            queryItems.append(URLQueryItem(name: "salonId", value: salonId.uuidString))
        }
        let response: APIResponse<[ClientRecall]> = try await request(path: "/clients/recall", queryItems: queryItems)
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

    // MARK: - Salons / Sedi
    
    func getSalons() async throws -> [Salon] {
        let response: APIResponse<[Salon]> = try await request(path: "/salons")
        return response.data ?? []
    }
    
    func getSalon(id: UUID) async throws -> Salon {
        let response: APIResponse<Salon> = try await request(path: "/salons/\(id)")
        guard let salon = response.data else { throw APIError.invalidResponse }
        return salon
    }
    
    func createSalon(_ request: CreateSalonRequest) async throws -> Salon {
        let response: APIResponse<Salon> = try await self.request(path: "/salons", method: "POST", body: request)
        guard let created = response.data else { throw APIError.invalidResponse }
        return created
    }
    
    func updateSalon(id: UUID, _ request: UpdateSalonRequest) async throws -> Salon {
        let response: APIResponse<Salon> = try await self.request(path: "/salons/\(id)", method: "PUT", body: request)
        guard let updated = response.data else { throw APIError.invalidResponse }
        return updated
    }
    
    func deleteSalon(id: UUID) async throws {
        try await requestNoContent(path: "/salons/\(id)", method: "DELETE")
    }
    
    func setDefaultSalon(id: UUID) async throws {
        let _: APIResponse<[String: String]> = try await request(path: "/salons/\(id)/default", method: "POST")
    }
    
    func checkSlugAvailability(slug: String, excludeId: UUID? = nil) async throws -> (available: Bool, cleanSlug: String) {
        var queryItems = [URLQueryItem(name: "slug", value: slug)]
        if let excludeId {
            queryItems.append(URLQueryItem(name: "excludeId", value: excludeId.uuidString))
        }
        let response: APIResponse<SlugCheckResult> = try await request(path: "/salons/check-slug", queryItems: queryItems)
        guard let data = response.data else { throw APIError.invalidResponse }
        return (data.available, data.slug)
    }
    
    func getSalonServices(salonId: UUID) async throws -> [SalonServiceItem] {
        let response: APIResponse<[SalonServiceItem]> = try await request(path: "/salons/\(salonId)/services")
        return response.data ?? []
    }
    
    func updateSalonServices(salonId: UUID, _ request: UpdateSalonServicesRequest) async throws {
        let _: APIResponse<[String: String]> = try await self.request(path: "/salons/\(salonId)/services", method: "PUT", body: request)
    }
    
    func getSalonHours(salonId: UUID) async throws -> [BusinessHourItem] {
        let response: APIResponse<[BusinessHourItem]> = try await request(path: "/salons/\(salonId)/hours")
        return response.data ?? []
    }
    
    func updateSalonHours(salonId: UUID, _ request: UpdateBusinessHoursRequest) async throws -> [BusinessHourItem] {
        let response: APIResponse<[BusinessHourItem]> = try await self.request(path: "/salons/\(salonId)/hours", method: "PUT", body: request)
        return response.data ?? []
    }

    // MARK: - Promotions
    
    func getPromotions(salonId: UUID? = nil) async throws -> [Promotion] {
        var queryItems: [URLQueryItem]? = nil
        if let salonId {
            queryItems = [URLQueryItem(name: "salonId", value: salonId.uuidString)]
        }
        let response: APIResponse<[Promotion]> = try await request(path: "/promotions", queryItems: queryItems)
        return response.data ?? []
    }
    
    func getActivePromotions(salonId: UUID? = nil) async throws -> [Promotion] {
        var queryItems: [URLQueryItem]? = nil
        if let salonId {
            queryItems = [URLQueryItem(name: "salonId", value: salonId.uuidString)]
        }
        let response: APIResponse<[Promotion]> = try await request(path: "/promotions/active", queryItems: queryItems)
        return response.data ?? []
    }
    
    func createPromotion(_ promotion: Promotion) async throws -> Promotion {
        let response: APIResponse<Promotion> = try await request(path: "/promotions", method: "POST", body: promotion)
        guard let created = response.data else { throw APIError.invalidResponse }
        return created
    }
    
    func updatePromotion(id: UUID, _ promotion: Promotion) async throws -> Promotion {
        let response: APIResponse<Promotion> = try await request(path: "/promotions/\(id)", method: "PUT", body: promotion)
        guard let updated = response.data else { throw APIError.invalidResponse }
        return updated
    }
    
    func deletePromotion(id: UUID) async throws {
        try await requestNoContent(path: "/promotions/\(id)", method: "DELETE")
    }
    
    // MARK: - Appointments
    
    func getAppointments(date: String? = nil, salonId: UUID? = nil) async throws -> [Appointment] {
        var queryItems: [URLQueryItem] = []
        if let date {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        if let salonId {
            queryItems.append(URLQueryItem(name: "salonId", value: salonId.uuidString))
        }
        let items = queryItems.isEmpty ? nil : queryItems
        let response: APIResponse<[Appointment]> = try await request(path: "/appointments", queryItems: items)
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
    
    func getDashboard(salonId: UUID? = nil) async throws -> DashboardData {
        var queryItems: [URLQueryItem]? = nil
        if let salonId {
            queryItems = [URLQueryItem(name: "salonId", value: salonId.uuidString)]
        }
        let response: APIResponse<DashboardData> = try await request(path: "/dashboard", queryItems: queryItems)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func getAdvancedStats(salonId: UUID? = nil) async throws -> AdvancedStats {
        var queryItems: [URLQueryItem]? = nil
        if let salonId {
            queryItems = [URLQueryItem(name: "salonId", value: salonId.uuidString)]
        }
        let response: APIResponse<AdvancedStats> = try await request(path: "/dashboard/stats", queryItems: queryItems)
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
        if let token = UserDefaults.standard.string(forKey: StorageKeys.authToken) {
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
    
    // MARK: - Expenses
    
    func getExpenses(month: String? = nil, category: String? = nil, salonId: UUID? = nil) async throws -> [Expense] {
        var path = "/expenses"
        var queryItems: [String] = []
        if let month { queryItems.append("month=\(month)") }
        if let category { queryItems.append("category=\(category)") }
        if let salonId { queryItems.append("salonId=\(salonId.uuidString)") }
        if !queryItems.isEmpty { path += "?" + queryItems.joined(separator: "&") }
        let response: APIResponse<[Expense]> = try await request(path: path)
        return response.data ?? []
    }
    
    func createExpense(_ expense: Expense) async throws -> Expense {
        let response: APIResponse<Expense> = try await request(path: "/expenses", method: "POST", body: expense)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func updateExpense(id: UUID, _ expense: Expense) async throws -> Expense {
        let response: APIResponse<Expense> = try await request(path: "/expenses/\(id)", method: "PUT", body: expense)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func deleteExpense(id: UUID) async throws {
        try await requestNoContent(path: "/expenses/\(id)", method: "DELETE")
    }
    
    func uploadExpensePhoto(expenseId: UUID, image: Data) async throws -> ExpensePhoto {
        let url = URL(string: "\(APIClient.baseServerURL)/expenses/\(expenseId)/photos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = UserDefaults.standard.string(forKey: StorageKeys.authToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
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
        
        let apiResponse = try decoder.decode(APIResponse<ExpensePhoto>.self, from: data)
        guard let photo = apiResponse.data else { throw APIError.invalidResponse }
        return photo
    }
    
    func deleteExpensePhoto(id: UUID) async throws {
        try await requestNoContent(path: "/expense-photos/\(id)", method: "DELETE")
    }
    
    // MARK: - Products & Stock (P4)
    func getProducts(salonId: UUID? = nil, search: String? = nil, category: String? = nil, lowStock: Bool? = nil) async throws -> [Product] {
        var queryItems: [String] = []
        if let salonId { queryItems.append("salonId=\(salonId.uuidString)") }
        if let search, !search.isEmpty { queryItems.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)") }
        if let category, !category.isEmpty { queryItems.append("category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)") }
        if let lowStock, lowStock { queryItems.append("lowStock=true") }
        
        var path = "/products"
        if !queryItems.isEmpty { path += "?" + queryItems.joined(separator: "&") }
        
        let response: APIResponse<[Product]> = try await request(path: path)
        return response.data ?? []
    }
    
    func getProduct(id: UUID) async throws -> Product {
        let response: APIResponse<Product> = try await request(path: "/products/\(id)")
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func createProduct(_ req: CreateProductRequest) async throws -> Product {
        let response: APIResponse<Product> = try await request(path: "/products", method: "POST", body: req)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func updateProduct(id: UUID, _ req: UpdateProductRequest) async throws -> Product {
        let response: APIResponse<Product> = try await request(path: "/products/\(id)", method: "PUT", body: req)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func deleteProduct(id: UUID) async throws {
        try await requestNoContent(path: "/products/\(id)", method: "DELETE")
    }
    
    func adjustStock(productId: UUID, salonId: UUID, delta: Int? = nil, quantity: Int? = nil) async throws -> ProductStock {
        let req = AdjustStockRequest(salonId: salonId, delta: delta, quantity: quantity)
        let response: APIResponse<ProductStock> = try await request(path: "/products/\(productId)/stock", method: "POST", body: req)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    // MARK: - Product Sales (P4)
    func getProductSales(salonId: UUID? = nil, clientId: UUID? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> [ProductSale] {
        var queryItems: [String] = []
        if let salonId { queryItems.append("salonId=\(salonId.uuidString)") }
        if let clientId { queryItems.append("clientId=\(clientId.uuidString)") }
        if let startDate { queryItems.append("startDate=\(startDate)") }
        if let endDate { queryItems.append("endDate=\(endDate)") }
        
        var path = "/product-sales"
        if !queryItems.isEmpty { path += "?" + queryItems.joined(separator: "&") }
        
        let response: APIResponse<[ProductSale]> = try await request(path: path)
        return response.data ?? []
    }
    
    func createProductSale(_ req: CreateProductSaleRequest) async throws -> ProductSale {
        let response: APIResponse<ProductSale> = try await request(path: "/product-sales", method: "POST", body: req)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }
    
    func deleteProductSale(id: UUID) async throws {
        try await requestNoContent(path: "/product-sales/\(id)", method: "DELETE")
    }
    
    // MARK: - Salon Staff
    func getSalonStaff(salonId: UUID) async throws -> [SalonMember] {
        let response: APIResponse<[SalonMember]> = try await request(path: "/salons/\(salonId.uuidString)/staff")
        return response.data ?? []
    }
    
    func resetCalendarToken(salonId: UUID, memberId: UUID) async throws -> SalonMember {
        let response: APIResponse<SalonMember> = try await request(
            path: "/salons/\(salonId.uuidString)/staff/\(memberId.uuidString)/calendar-token/reset",
            method: "POST"
        )
        guard let data = response.data else {
            throw APIError.serverError("Impossibile reimpostare il token del calendario")
        }
        return data
    }
}
