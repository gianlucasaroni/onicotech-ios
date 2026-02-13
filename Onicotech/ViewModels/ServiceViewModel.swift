import Foundation
import Observation

@Observable
@MainActor
class ServiceViewModel {
    var services: [Service] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false
    
    private let api = APIClient.shared
    
    var activeServices: [Service] {
        services.filter { $0.active }
    }
    
    func loadServices() async {
        isLoading = true
        errorMessage = nil
        do {
            services = try await api.getServices()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func createService(_ service: Service) async -> Bool {
        do {
            let created = try await api.createService(service)
            services.append(created)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func updateService(id: UUID, _ service: Service) async -> Bool {
        do {
            let updated = try await api.updateService(id: id, service)
            if let index = services.firstIndex(where: { $0.id == id }) {
                services[index] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func toggleActive(service: Service) async {
        guard let id = service.id else { return }
        var updated = service
        updated.active.toggle()
        _ = await updateService(id: id, updated)
    }
    
    func deleteService(id: UUID) async -> Bool {
        do {
            try await api.deleteService(id: id)
            services.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}
