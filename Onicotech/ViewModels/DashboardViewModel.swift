import Foundation
import Observation

@Observable
@MainActor
class DashboardViewModel {
    var data: DashboardData?
    var nextFreeSlot: NextFreeSlot?
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
    
    var pendingBookingsCount: Int {
        nextAppointments.filter { $0.status == .pending }.count
    }
    
    private let api = APIClient.shared
    
    func loadData(salonId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            async let dashboardData = api.getDashboard(salonId: salonId)
            async let freeSlot = api.getNextFreeSlot(salonId: salonId)
            data = try await dashboardData
            nextFreeSlot = try await freeSlot
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}
