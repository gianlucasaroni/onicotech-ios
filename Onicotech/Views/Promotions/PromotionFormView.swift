import SwiftUI

struct PromotionFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: PromotionViewModel
    var promotionToEdit: Promotion?
    
    @State private var name = ""
    @State private var description = ""
    @State private var discountPercent: Double = 10
    @State private var active = true
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date().addingTimeInterval(86400 * 30) // +30 days
    
    // Client selection
    @State private var clientViewModel = ClientViewModel()
    @State private var selectedClients: Set<UUID> = []
    
    var isEditing: Bool { promotionToEdit != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Nome Promozione", text: $name)
                    TextField("Descrizione (opzionale)", text: $description)
                    
                    VStack(alignment: .leading) {
                        Text("Sconto: \(Int(discountPercent))%")
                        Slider(value: $discountPercent, in: 0...100, step: 1)
                    }
                    
                    Toggle("Attiva", isOn: $active)
                }
                
                Section("Validità") {
                    Toggle("Data Inizio", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("Inizio", selection: $startDate, displayedComponents: [.date])
                    }
                    
                    Toggle("Data Fine", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fine", selection: $endDate, displayedComponents: [.date])
                    }
                }
                
                Section("Applica ai Clienti") {
                    if clientViewModel.isLoading && clientViewModel.clients.isEmpty {
                        ProgressView()
                    } else if clientViewModel.clients.isEmpty {
                        Text("Nessun cliente disponibile")
                            .foregroundStyle(.secondary)
                    } else {
                        List(clientViewModel.clients) { client in
                            Button {
                                if selectedClients.contains(client.id ?? UUID()) {
                                    selectedClients.remove(client.id ?? UUID())
                                } else {
                                    selectedClients.insert(client.id ?? UUID())
                                }
                            } label: {
                                HStack {
                                    Text("\(client.firstName) \(client.lastName)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedClients.contains(client.id ?? UUID()) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica Promozione" : "Nuova Promozione")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await clientViewModel.loadClients()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        save()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let promo = promotionToEdit {
                    name = promo.name
                    description = promo.description ?? ""
                    discountPercent = promo.discountPercent
                    active = promo.active
                    if let start = promo.startDate {
                        hasStartDate = true
                        startDate = start
                    }
                    if let end = promo.endDate {
                        hasEndDate = true
                        endDate = end
                    }
                    if let clients = promo.clientIds {
                        selectedClients = Set(clients)
                    }
                }
            }
        }
    }
    
    private func save() {
        let newPromo = Promotion(
            id: promotionToEdit?.id ?? UUID(),
            userId: UUID(), // Placeholder, backend sets this
            name: name,
            description: description.isEmpty ? nil : description,
            discountPercent: discountPercent,
            startDate: hasStartDate ? startDate : nil,
            endDate: hasEndDate ? endDate : nil,
            active: active,
            clientIds: Array(selectedClients),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        Task {
            let success: Bool
            if isEditing {
                success = await viewModel.updatePromotion(id: newPromo.id, newPromo)
            } else {
                success = await viewModel.createPromotion(newPromo)
            }
            
            if success {
                dismiss()
            }
        }
    }
}
