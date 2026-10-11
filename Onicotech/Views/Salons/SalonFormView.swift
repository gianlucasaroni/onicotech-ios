import SwiftUI

struct SalonFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var viewModel: SalonViewModel
    var salonToEdit: Salon?
    
    @State private var name = ""
    @State private var address = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""
    @State private var isDefault = false
    @State private var active = true
    @State private var isSaving = false
    
    private var isEditing: Bool { salonToEdit != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dati Principali") {
                    TextField("Nome Sede (es. Studio Milano) *", text: $name)
                    
                    Toggle("Sede Predefinita", isOn: $isDefault)
                    if isEditing {
                        Toggle("Attiva", isOn: $active)
                    }
                }
                
                Section("Posizione") {
                    TextField("Indirizzo (Via / Piazza e N°)", text: $address)
                    TextField("Città", text: $city)
                    TextField("CAP", text: $postalCode)
                }
                
                Section("Contatti") {
                    TextField("Telefono", text: $phone)
                    TextField("Email", text: $email)
                }
                
                Section("Note Interne") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(isEditing ? "Modifica Sede" : "Nuova Sede")
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
            .onAppear {
                if let salon = salonToEdit {
                    name = salon.name
                    address = salon.address ?? ""
                    city = salon.city ?? ""
                    postalCode = salon.postalCode ?? ""
                    phone = salon.phone ?? ""
                    email = salon.email ?? ""
                    notes = salon.notes ?? ""
                    isDefault = salon.isDefault
                    active = salon.active
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func save() async {
        guard isValid else { return }
        isSaving = true
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let addr = address.isEmpty ? nil : address
        let c = city.isEmpty ? nil : city
        let cap = postalCode.isEmpty ? nil : postalCode
        let ph = phone.isEmpty ? nil : phone
        let em = email.isEmpty ? nil : email
        let nt = notes.isEmpty ? nil : notes
        
        let success: Bool
        if let id = salonToEdit?.id {
            let req = UpdateSalonRequest(
                name: trimmedName,
                address: addr,
                city: c,
                postalCode: cap,
                phone: ph,
                email: em,
                notes: nt,
                isDefault: isDefault,
                active: active
            )
            success = await viewModel.updateSalon(id: id, req)
        } else {
            let req = CreateSalonRequest(
                name: trimmedName,
                address: addr,
                city: c,
                postalCode: cap,
                phone: ph,
                email: em,
                notes: nt,
                isDefault: isDefault
            )
            success = await viewModel.createSalon(req)
        }
        
        isSaving = false
        if success {
            await salonManager.loadSalons()
            dismiss()
        }
    }
}
