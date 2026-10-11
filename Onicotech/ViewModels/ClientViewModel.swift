import Foundation
import Observation

@Observable
@MainActor
class ClientViewModel {
    var clients: [Client] = []
    var isLoading = false
    var recallClients: [ClientRecall] = []
    var isRecallLoading = false
    var recallDaysFilter = 21
    var errorMessage: String?
    var showError = false
    
    private let api = APIClient.shared
    
    func loadClients() async {
        isLoading = true
        errorMessage = nil
        do {
            clients = try await api.getClients()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func loadRecallClients(days: Int? = nil, salonId: UUID? = nil) async {
        let filterDays = days ?? recallDaysFilter
        recallDaysFilter = filterDays
        isRecallLoading = true
        do {
            recallClients = try await api.getRecallClients(days: filterDays, salonId: salonId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isRecallLoading = false
    }
    
    func loadAll(days: Int? = nil, salonId: UUID? = nil) async {
        async let c: () = loadClients()
        async let r: () = loadRecallClients(days: days, salonId: salonId)
        _ = await (c, r)
    }
    
    func createClient(_ client: Client) async -> Bool {
        do {
            let created = try await api.createClient(client)
            clients.append(created)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func updateClient(id: UUID, _ client: Client) async -> Bool {
        do {
            let updated = try await api.updateClient(id: id, client)
            if let index = clients.firstIndex(where: { $0.id == id }) {
                clients[index] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func deleteClient(at offsets: IndexSet) async {
        for index in offsets {
            let client = clients[index]
            guard let id = client.id else { continue }
            do {
                try await api.deleteClient(id: id)
                clients.remove(at: index)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    func deleteClient(id: UUID) async -> Bool {
        do {
            try await api.deleteClient(id: id)
            clients.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}
