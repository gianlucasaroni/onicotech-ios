import Foundation
import SwiftUI
import Combine

@MainActor
final class SalonViewModel: ObservableObject {
    @Published var salons: [Salon] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Salon Services
    @Published var salonServices: [SalonServiceItem] = []
    @Published var isLoadingServices = false
    
    // Salon Business Hours
    @Published var salonHours: [BusinessHourItem] = []
    @Published var isLoadingHours = false
    
    func loadSalons() async {
        isLoading = true
        errorMessage = nil
        do {
            salons = try await APIClient.shared.getSalons()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func createSalon(_ request: CreateSalonRequest) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let created = try await APIClient.shared.createSalon(request)
            salons.append(created)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    func updateSalon(id: UUID, _ request: UpdateSalonRequest) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let updated = try await APIClient.shared.updateSalon(id: id, request)
            if let index = salons.firstIndex(where: { $0.id == id }) {
                salons[index] = updated
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
    
    func deleteSalon(id: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await APIClient.shared.deleteSalon(id: id)
            salons.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func setDefaultSalon(id: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await APIClient.shared.setDefaultSalon(id: id)
            for i in salons.indices {
                salons[i].isDefault = (salons[i].id == id)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    // MARK: - Services
    
    func loadSalonServices(salonId: UUID) async {
        isLoadingServices = true
        errorMessage = nil
        do {
            salonServices = try await APIClient.shared.getSalonServices(salonId: salonId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoadingServices = false
    }
    
    func saveSalonServices(salonId: UUID, items: [SalonServiceItem]) async -> Bool {
        isLoadingServices = true
        errorMessage = nil
        do {
            let dtos = items.map { item in
                SalonServiceUpdateDTO(
                    serviceId: item.serviceId,
                    priceOverride: item.priceOverride,
                    active: item.active
                )
            }
            try await APIClient.shared.updateSalonServices(salonId: salonId, UpdateSalonServicesRequest(services: dtos))
            self.salonServices = items
            isLoadingServices = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoadingServices = false
            return false
        }
    }
    
    // MARK: - Business Hours
    
    func loadSalonHours(salonId: UUID) async {
        isLoadingHours = true
        errorMessage = nil
        do {
            let hours = try await APIClient.shared.getSalonHours(salonId: salonId)
            self.salonHours = hours.sorted { $0.dayOfWeek < $1.dayOfWeek }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoadingHours = false
    }
    
    func saveSalonHours(salonId: UUID, hours: [BusinessHourItem]) async -> Bool {
        isLoadingHours = true
        errorMessage = nil
        do {
            let saved = try await APIClient.shared.updateSalonHours(salonId: salonId, UpdateBusinessHoursRequest(hours: hours))
            self.salonHours = saved.sorted { $0.dayOfWeek < $1.dayOfWeek }
            isLoadingHours = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoadingHours = false
            return false
        }
    }
}
