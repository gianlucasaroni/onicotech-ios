import Foundation
import SwiftUI
import Combine

@MainActor
final class SalonManager: ObservableObject {
    @Published var salons: [Salon] = []
    @Published var selectedSalon: Salon? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let userDefaultsKey = "selectedSalonId"
    
    var selectedSalonId: UUID? {
        selectedSalon?.id
    }
    
    var hasMultipleSalons: Bool {
        salons.count > 1
    }
    
    var defaultSalon: Salon? {
        salons.first(where: { $0.isDefault }) ?? salons.first
    }
    
    init() {
        // Will be populated when user logs in or on demand
    }
    
    func selectSalon(_ salon: Salon?) {
        selectedSalon = salon
        if let id = salon?.id {
            UserDefaults.standard.set(id.uuidString, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.set("all", forKey: userDefaultsKey)
        }
    }
    
    func loadSalons() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedSalons = try await APIClient.shared.getSalons()
            self.salons = loadedSalons
            self.restoreSelection()
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func restoreSelection() {
        guard !salons.isEmpty else {
            selectedSalon = nil
            return
        }
        
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey)
        if saved == "all" {
            selectedSalon = nil
            return
        }
        
        if let saved, let uuid = UUID(uuidString: saved), let found = salons.first(where: { $0.id == uuid }) {
            selectedSalon = found
            return
        }
        
        // If single salon, auto-select it. Otherwise if there is a default salon, default to it.
        if salons.count == 1 {
            selectedSalon = salons.first
        } else if let def = salons.first(where: { $0.isDefault }) {
            selectedSalon = def
        } else {
            selectedSalon = nil // Tutte le sedi
        }
    }
}
