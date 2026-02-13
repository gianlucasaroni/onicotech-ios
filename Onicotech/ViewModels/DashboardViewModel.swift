import Foundation
import Observation

@Observable
@MainActor
class DashboardViewModel {
    var data: DashboardData?
    var isLoading = false
    var errorMessage: String?
    var showError = false
    
    // Computed properties for UI
    var nextAppointments: [Appointment] {
        data?.nextAppointments ?? []
    }
    
    var totalClients: Int {
        data?.totalClients ?? 0
    }
    
    var newClients: Int {
        data?.newClientsThisMonth ?? 0
    }
    
    var monthlyEarnings: String {
        let value = Double(data?.monthlyEarnings ?? 0) / 100.0
        return String(format: "€%.2f", value)
    }
    
    private let api = APIClient.shared
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            data = try await api.getDashboard()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}
