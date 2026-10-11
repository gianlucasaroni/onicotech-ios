import SwiftUI

struct SalonServicesView: View {
    let salon: Salon
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SalonViewModel()
    
    @State private var allServices: [Service] = []
    @State private var serviceSelections: [UUID: ServiceSalonConfig] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSavedAlert = false
    
    struct ServiceSalonConfig {
        var active: Bool
        var priceText: String // in euros, e.g. "35.00"
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Caricamento listino...")
            } else if allServices.isEmpty {
                ContentUnavailableView(
                    "Nessun servizio nel catalogo",
                    systemImage: "scissors",
                    description: Text("Crea prima i servizi globali nella sezione Gestione > Servizi")
                )
            } else {
                Form {
                    Section {
                        Text("Configura quali servizi sono disponibili nella sede **\(salon.name)**. Puoi lasciare il prezzo base del catalogo oppure inserire un prezzo dedicato.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(allServices) { service in
                        if let serviceId = service.id {
                            Section(header: Text(service.name)) {
                                Toggle("Disponibile in questa sede", isOn: Binding(
                                    get: { serviceSelections[serviceId]?.active ?? true },
                                    set: { newValue in
                                        var cfg = serviceSelections[serviceId] ?? ServiceSalonConfig(active: true, priceText: "")
                                        cfg.active = newValue
                                        serviceSelections[serviceId] = cfg
                                    }
                                ))
                                
                                HStack {
                                    Text("Prezzo dedicato")
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("€")
                                            .foregroundStyle(.secondary)
                                        TextField(
                                            String(format: "%.2f (base)", Double(service.price) / 100.0),
                                            text: Binding(
                                                get: { serviceSelections[serviceId]?.priceText ?? "" },
                                                set: { newValue in
                                                    var cfg = serviceSelections[serviceId] ?? ServiceSalonConfig(active: true, priceText: "")
                                                    cfg.priceText = newValue
                                                    serviceSelections[serviceId] = cfg
                                                }
                                            )
                                        )
                                        .decimalKeyboard()
                                        .frame(width: 100)
                                        .multilineTextAlignment(.trailing)
                                    }
                                }
                                
                                HStack {
                                    Text("Durata:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(service.formattedDuration)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if let cfg = serviceSelections[serviceId], !cfg.priceText.isEmpty {
                                        Text("Prezzo personalizzato attivo")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("Usa prezzo catalogo")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Listino · \(salon.name)")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Salva") {
                        Task { await save() }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .alert("Listino Aggiornato", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("I prezzi e i servizi per la sede '\(salon.name)' sono stati salvati con successo.")
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            async let fetchServices = APIClient.shared.getServices()
            async let fetchSalonServices = APIClient.shared.getSalonServices(salonId: salon.id)
            
            let services = try await fetchServices
            let salonServiceItems = try await fetchSalonServices
            
            self.allServices = services
            
            var configs: [UUID: ServiceSalonConfig] = [:]
            for s in services {
                guard let sid = s.id else { continue }
                if let found = salonServiceItems.first(where: { $0.serviceId == sid }) {
                    let priceStr = found.priceOverride != nil ? String(format: "%.2f", Double(found.priceOverride!) / 100.0) : ""
                    configs[sid] = ServiceSalonConfig(active: found.active, priceText: priceStr)
                } else {
                    configs[sid] = ServiceSalonConfig(active: true, priceText: "")
                }
            }
            self.serviceSelections = configs
        } catch {
            print("Error loading salon services: \(error)")
        }
        isLoading = false
    }
    
    private func save() async {
        isSaving = true
        
        var items: [SalonServiceItem] = []
        for service in allServices {
            guard let sid = service.id else { continue }
            let cfg = serviceSelections[sid] ?? ServiceSalonConfig(active: true, priceText: "")
            
            var overrideCents: Int? = nil
            let cleaned = cfg.priceText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            if let val = Double(cleaned), val > 0 {
                overrideCents = Int(val * 100)
            }
            
            items.append(SalonServiceItem(
                salonId: salon.id,
                serviceId: sid,
                service: service,
                priceOverride: overrideCents,
                active: cfg.active,
                createdAt: nil,
                updatedAt: nil
            ))
        }
        
        let success = await viewModel.saveSalonServices(salonId: salon.id, items: items)
        isSaving = false
        if success {
            showSavedAlert = true
        }
    }
}
