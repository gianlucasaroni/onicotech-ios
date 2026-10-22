import SwiftUI

struct ServiceFormView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: ServiceViewModel
    
    var service: Service?
    
    @State private var name = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var durationText = ""
    @State private var showInOnlineBooking = true
    @State private var active = true
    @State private var isSaving = false
    
    private var isEditing: Bool { service != nil }
    
    private var isValid: Bool {
        !name.isEmpty &&
        (Double(priceText) ?? 0) > 0 &&
        (Int(durationText) ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Nome servizio *", text: $name)
                    TextField("Descrizione", text: $description)
                }
                
                Section("Prezzo e Durata") {
                    HStack {
                        Text("€")
                        TextField("Prezzo *", text: $priceText)
                            .decimalKeyboard()
                    }
                    HStack {
                        TextField("Durata (min)", text: $durationText)
                            .numberKeyboard()
                        Text("minuti")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Prenotazione Online") {
                    Toggle("Visibile nella Prenotazione Online", isOn: $showInOnlineBooking)
                    Text("Se attivo, le clienti potranno selezionare questo trattamento dalla pagina web di prenotazione.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if isEditing {
                    Section {
                        Toggle("Attivo", isOn: $active)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica Servizio" : "Nuovo Servizio")
            .inlineNavigationTitle()
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Salva" : "Crea") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                if let service {
                    name = service.name
                    description = service.description ?? ""
                    let priceDecimal = Double(service.price) / 100.0
                    priceText = String(format: "%.2f", priceDecimal)
                    durationText = "\(service.duration)"
                    showInOnlineBooking = service.showInOnlineBooking ?? true
                    active = service.active
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func save() async {
        isSaving = true
        let priceValue = (Double(priceText) ?? 0) * 100
        
        var newService = Service(
            id: service?.id, // Preserve ID for update
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            price: Int(priceValue),
            duration: Int(durationText) ?? 0,
            active: active,
            showInOnlineBooking: showInOnlineBooking
        )
        
        let success: Bool
        if let id = service?.id {
            success = await viewModel.updateService(id: id, newService)
        } else {
            // ID is nil for create, backend assigns it
            newService.id = nil 
            success = await viewModel.createService(newService)
        }
        
        isSaving = false
        if success {
            Haptics.play(.success)
            dismiss()
        }
    }
}
