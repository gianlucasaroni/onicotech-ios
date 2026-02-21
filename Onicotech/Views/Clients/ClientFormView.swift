import SwiftUI
import Foundation

struct ClientFormView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: ClientViewModel
    
    var client: Client?
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""
    @State private var selectedPromotionIds: Set<UUID> = []
    @State private var promotions: [Promotion] = []
    @State private var isSaving = false
    
    private var isEditing: Bool { client != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informazioni") {
                    TextField("Nome *", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Cognome *", text: $lastName)
                        .textContentType(.familyName)
                }
                
                Section("Contatti") {
                    TextField("Telefono", text: $phone)
                        .textContentType(.telephoneNumber)
                        .phoneKeyboard()
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .emailKeyboard()
                        
                }
                
                Section("Note") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section("Promozioni Default") {
                    if promotions.isEmpty {
                        Text("Nessuna promozione disponibile")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(promotions) { promo in
                            Button {
                                if selectedPromotionIds.contains(promo.id) {
                                    selectedPromotionIds.remove(promo.id)
                                } else {
                                    selectedPromotionIds.insert(promo.id)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(promo.name)
                                            .foregroundStyle(.primary)
                                        Text("-\(Int(promo.discountPercent))%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedPromotionIds.contains(promo.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica Cliente" : "Nuovo Cliente")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Salva" : "Crea") {
                        Task { await save() }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || isSaving)
                }
            }
            .onAppear {
                if let client {
                    firstName = client.firstName
                    lastName = client.lastName
                    phone = client.phone ?? ""
                    email = client.email ?? ""
                    notes = client.notes ?? ""
                    selectedPromotionIds = Set(client.promotionIds)
                }
                
                Task {
                    do {
                        let allPromos = try await APIClient.shared.getActivePromotions()
                        promotions = allPromos
                    } catch {
                        print("Failed to load promotions: \(error)")
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func save() async {
        isSaving = true
        let newClient = Client(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            notes: notes.isEmpty ? nil : notes,
            promotionIds: Array(selectedPromotionIds)
        )
        
        let success: Bool
        if let id = client?.id {
            success = await viewModel.updateClient(id: id, newClient)
        } else {
            success = await viewModel.createClient(newClient)
        }
        
        isSaving = false
        if success { dismiss() }
    }
}
