import Foundation
import Observation

@Observable
class StatisticsViewModel {
    var stats: AdvancedStats?
    var isLoading = false
    var errorMessage: String?
    var showError = false
    
    private let api = APIClient.shared
    
    func loadStats() async {
        isLoading = true
        errorMessage = nil
        do {
            stats = try await api.getAdvancedStats()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    // Sample data for preview/testing if needed
    func loadMockData() {
        // Implement if needed
    }
}
