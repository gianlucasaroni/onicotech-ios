import SwiftUI
import Foundation

struct AppointmentFormView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: AppointmentViewModel
    
    var appointment: Appointment?
    var preselectedClientId: UUID? = nil
    var preselectedDate: Date? = nil
    
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var selectedClientId: UUID?
    @State private var selectedServiceIds: Set<UUID> = []
    @State private var notes = ""
    @State private var status: AppointmentStatus = .scheduled
    @State private var isSaving = false
    
    // Data sources
    @State private var clients: [Client] = []
    @State private var services: [Service] = []
    @State private var promotions: [Promotion] = []
    @State private var selectedPromotionId: UUID?
    @State private var isLoadingData = true
    
    private var isEditing: Bool { appointment != nil }
    
    private var isValid: Bool {
        selectedClientId != nil && !selectedServiceIds.isEmpty
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if isLoadingData {
                    ProgressView("Caricamento dati...")
                } else {
                    Form {
                        Section("Data e Ora") {
                            DatePicker("Data", selection: $date, displayedComponents: .date)
                            DatePicker("Ora inizio", selection: $startTime, displayedComponents: .hourAndMinute)
                        }
                        
                        Section("Cliente") {
                            if clients.isEmpty {
                                Text("Nessun cliente disponibile")
                                    .foregroundStyle(.secondary)
                            } else if preselectedClientId != nil, let client = clients.first(where: { $0.id == preselectedClientId }) {
                                // Client is pre-selected and locked
                                HStack {
                                    Label(client.fullName, systemImage: "person.fill")
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Picker("Seleziona cliente", selection: $selectedClientId) {
                                    Text("Seleziona...").tag(nil as UUID?)
                                    ForEach(clients) { client in
                                        Text(client.fullName).tag(client.id as UUID?)
                                    }
                                }
                            }
                        }
                        
                        Section("Servizi") {
                            if services.isEmpty {
                                Text("Nessun servizio disponibile")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(services.filter { $0.active }) { service in
                                    Button {
                                        if let id = service.id {
                                            if selectedServiceIds.contains(id) {
                                                selectedServiceIds.remove(id)
                                            } else {
                                                selectedServiceIds.insert(id)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(service.name)
                                                    .foregroundStyle(.primary)
                                                Text("\(service.formattedPrice) · \(service.formattedDuration)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if let id = service.id, selectedServiceIds.contains(id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                }
                                
                                if !selectedServiceIds.isEmpty {
                                    let total = services
                                        .filter { $0.id != nil && selectedServiceIds.contains($0.id!) }
                                        .reduce(0) { $0 + $1.price }
                                    let totalDuration = services
                                        .filter { $0.id != nil && selectedServiceIds.contains($0.id!) }
                                        .reduce(0) { $0 + $1.duration }
                                    
                                    // Calculate Discount
                                    let discountAmount = calculateDiscount(total: total)
                                    let finalPrice = max(0, total - discountAmount)
                                    
                                    VStack(spacing: 4) {
                                        HStack {
                                            Text("Subtotale:")
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(String(format: "€%.2f", Double(total) / 100.0))
                                                .strikethrough(discountAmount > 0)
                                        }
                                        
                                        if discountAmount > 0 {
                                            HStack {
                                                Text("Sconto:")
                                                    .foregroundStyle(.green)
                                                Spacer()
                                                Text(String(format: "-€%.2f", Double(discountAmount) / 100.0))
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        
                                        HStack {
                                            Text("Totale:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(String(format: "€%.2f · %d min", Double(finalPrice) / 100.0, totalDuration))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .font(.subheadline)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        
                        Section("Promozione") {
                            Picker("Applica Promozione", selection: $selectedPromotionId) {
                                Text("Nessuna").tag(Optional<UUID>.none)
                                ForEach(promotions) { promo in
                                    Text(promo.name + " (-\(Int(promo.discountPercent))%)").tag(Optional(promo.id))
                                }
                            }
                        }
                        
                        Section("Note") {
                            TextEditor(text: $notes)
                                .frame(minHeight: 60)
                        }
                        
                        if isEditing {
                            Section("Stato") {
                                Picker("Stato", selection: $status) {
                                    ForEach(AppointmentStatus.allCases, id: \.self) { s in
                                        Label(s.displayName, systemImage: s.iconName)
                                            .tag(s)
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: selectedClientId) { _, newValue in
                        onClientChange(newClientId: newValue)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica Appuntamento" : "Nuovo Appuntamento")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Salva" : "Crea") {
                            Task { await save() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .alert("Errore", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Si è verificato un errore sconosciuto")
            }
            .task {
                await loadFormData()
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func loadFormData() async {
        isLoadingData = true
        do {
            async let fetchClients = APIClient.shared.getClients()
            async let fetchServices = APIClient.shared.getServices()
            async let fetchPromotions = APIClient.shared.getActivePromotions()
            clients = try await fetchClients
            services = try await fetchServices
            promotions = try await fetchPromotions
        } catch {
            // Silently handle — the empty state UI will guide the user
        }
        
        // Populate form if editing
        if let appointment {
            let df = dateFormatter
            let timeF = timeFormatter
            if let d = df.date(from: appointment.date) { date = d }
            if let t = timeF.date(from: appointment.startTime) { startTime = t }
            selectedClientId = appointment.clientId
            if let svcIds = appointment.services?.compactMap(\.id) {
                selectedServiceIds = Set(svcIds)
            }
            notes = appointment.notes ?? ""
            status = appointment.status ?? .scheduled
            selectedPromotionId = appointment.promotionId
        } else {
            // Apply preselections for new appointments
            if let preselectedClientId {
                selectedClientId = preselectedClientId
                // Auto-select client's promo if they have exactly one
                if let client = clients.first(where: { $0.id == preselectedClientId }) {
                    let validPromoIds = client.promotionIds.filter { pid in
                        promotions.contains(where: { $0.id == pid })
                    }
                    if validPromoIds.count == 1 {
                        selectedPromotionId = validPromoIds.first
                    }
                }
            }
            if let preselectedDate {
                date = preselectedDate
            }
        }
        
        isLoadingData = false
    }
    
    // Watch for client selection change to auto-apply promotion
    func onClientChange(newClientId: UUID?) {
        guard appointment == nil else { return } // Only auto-apply for new appointments
        
        if let clientId = newClientId,
           let client = clients.first(where: { $0.id == clientId }) {
            let validPromoIds = client.promotionIds.filter { pid in
                promotions.contains(where: { $0.id == pid })
            }
            if validPromoIds.count == 1 {
                selectedPromotionId = validPromoIds.first
            } else {
                selectedPromotionId = nil
            }
        } else {
            selectedPromotionId = nil
        }
    }
    
    private func save() async {
        guard let clientId = selectedClientId else { return }
        isSaving = true
        
        let dateStr = dateFormatter.string(from: date)
        let timeStr = timeFormatter.string(from: startTime)
        let serviceIdArray = Array(selectedServiceIds)
        
        let success: Bool
        if let id = appointment?.id {
            let request = UpdateAppointmentRequest(
                date: dateStr,
                startTime: timeStr,
                clientId: clientId,
                serviceIds: serviceIdArray,
                notes: notes.isEmpty ? nil : notes,
                promotionId: selectedPromotionId,
                status: status
            )
            success = await viewModel.updateAppointment(id: id, request: request)
        } else {
            let request = CreateAppointmentRequest(
                date: dateStr,
                startTime: timeStr,
                clientId: clientId,
                serviceIds: serviceIdArray,
                notes: notes.isEmpty ? nil : notes,
                promotionId: selectedPromotionId
            )
            success = await viewModel.createAppointment(request: request)
        }
        
        isSaving = false
        if success { dismiss() }
    }
    
    private func calculateDiscount(total: Int) -> Int {
        guard let promoId = selectedPromotionId,
              let promo = promotions.first(where: { $0.id == promoId }) else { return 0 }
        return Int(Double(total) * promo.discountPercent / 100.0)
    }
}
    

