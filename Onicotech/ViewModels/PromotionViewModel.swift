import SwiftUI
import Combine

@MainActor
class PromotionViewModel: ObservableObject {
    @Published var promotions: [Promotion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    func loadPromotions() async {
        isLoading = true
        errorMessage = nil
        do {
            promotions = try await APIClient.shared.getPromotions()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func createPromotion(_ promotion: Promotion) async -> Bool {
        isLoading = true
        do {
            let created = try await APIClient.shared.createPromotion(promotion)
            promotions.insert(created, at: 0)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    func updatePromotion(id: UUID, _ promotion: Promotion) async -> Bool {
        isLoading = true
        do {
            let updated = try await APIClient.shared.updatePromotion(id: id, promotion)
            if let index = promotions.firstIndex(where: { $0.id == id }) {
                promotions[index] = updated
            }
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    func deletePromotion(id: UUID) async -> Bool {
        do {
            try await APIClient.shared.deletePromotion(id: id)
            promotions.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}
