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
    @State private var nailType = ""
    @State private var allergies = ""
    @State private var preferredShape = ""
    @State private var technicalNotes = ""
    @State private var customerTag = ""
    @State private var birthDay: Int? = nil
    @State private var birthMonth: Int? = nil
    @State private var birthYearText = ""
    @State private var selectedPromotionIds: Set<UUID> = []
    @State private var promotions: [Promotion] = []
    @State private var isSaving = false
    
    private let italianMonths = [
        (1, "Gennaio"), (2, "Febbraio"), (3, "Marzo"), (4, "Aprile"),
        (5, "Maggio"), (6, "Giugno"), (7, "Luglio"), (8, "Agosto"),
        (9, "Settembre"), (10, "Ottobre"), (11, "Novembre"), (12, "Dicembre")
    ]
    
    private let nailTypes = [
        "Standard / Naturale",
        "Sottile / Fragile",
        "Onicofagica",
        "Grassa / Con Iperidrosi",
        "Secca / Disidratata"
    ]

    private let nailShapes = [
        "Mandorla",
        "Quadrata",
        "Squoval",
        "Ovale",
        "Ballerina / Coffin",
        "Stiletto",
        "Corta Naturale"
    ]

    private let customerTags = [
        "VIP",
        "Nuova Cliente",
        "Fedele",
        "Super Puntuale",
        "Esigente"
    ]

    private let allergyPresets = [
        "HEMA-Free",
        "Di-HEMA",
        "Acrilati",
        "Nickel",
        "Acetone"
    ]
    
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
                
                Section("Scheda Tecnica Nail & Sicurezza") {
                    Picker("Tag Profilo", selection: $customerTag) {
                        Text("Nessun Tag").tag("")
                        ForEach(customerTags, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }
                    
                    Picker("Tipologia Unghia", selection: $nailType) {
                        Text("Non specificata").tag("")
                        ForEach(nailTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    Picker("Forma Preferita", selection: $preferredShape) {
                        Text("Non specificata").tag("")
                        ForEach(nailShapes, id: \.self) { shape in
                            Text(shape).tag(shape)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Allergie & Sensibilità", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                        TextField("es. HEMA-Free, Acrilati, Nickel...", text: $allergies)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(allergyPresets, id: \.self) { preset in
                                    Button {
                                        toggleAllergyPreset(preset)
                                    } label: {
                                        Text(preset)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(isAllergyActive(preset) ? Color.red : Color.red.opacity(0.1))
                                            .foregroundStyle(isAllergyActive(preset) ? Color.white : Color.red)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Basi, Costruttore e Colori")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $technicalNotes)
                            .frame(minHeight: 60)
                    }
                }
                
                Section("Contatti") {
                    if client?.isPhoneMasked == true {
                        HStack {
                            Label("Telefono", systemImage: "lock.fill")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(phone)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Telefono", text: $phone)
                            .textContentType(.telephoneNumber)
                            .phoneKeyboard()
                    }
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .emailKeyboard()
                }

                Section("Compleanno (Giorno / Mese, Anno facoltativo)") {
                    HStack {
                        Picker("Giorno", selection: $birthDay) {
                            Text("--").tag(nil as Int?)
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Mese", selection: $birthMonth) {
                            Text("--").tag(nil as Int?)
                            ForEach(italianMonths, id: \.0) { m in
                                Text(m.1).tag(m.0 as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Anno (facoltativo)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("es. 1995", text: $birthYearText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    
                    if birthDay != nil && birthMonth == nil {
                        Text("Seleziona anche il mese del compleanno")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if birthMonth != nil && birthDay == nil {
                        Text("Seleziona anche il giorno del compleanno")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section("Altre Note") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
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
                    nailType = client.nailType ?? ""
                    allergies = client.allergies ?? ""
                    preferredShape = client.preferredShape ?? ""
                    technicalNotes = client.technicalNotes ?? ""
                    customerTag = client.customerTag ?? ""
                    birthDay = client.birthDay
                    birthMonth = client.birthMonth
                    if let year = client.birthYear {
                        birthYearText = String(year)
                    }
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
    
    private func toggleAllergyPreset(_ preset: String) {
        var items = allergies
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let idx = items.firstIndex(where: { $0.localizedCaseInsensitiveCompare(preset) == .orderedSame }) {
            items.remove(at: idx)
        } else {
            items.append(preset)
        }
        allergies = items.joined(separator: ", ")
    }
    
    private func isAllergyActive(_ preset: String) -> Bool {
        allergies
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .contains(preset.lowercased())
    }
    
    private func save() async {
        isSaving = true
        let yearParsed = Int(birthYearText.trimmingCharacters(in: .whitespaces))
        let hasBirthday = birthDay != nil && birthMonth != nil
        let newClient = Client(
            id: client?.id,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phone: client?.isPhoneMasked == true ? nil : (phone.isEmpty ? nil : phone),
            email: email.isEmpty ? nil : email,
            notes: notes.isEmpty ? nil : notes,
            nailType: nailType.isEmpty ? nil : nailType,
            allergies: allergies.isEmpty ? nil : allergies,
            preferredShape: preferredShape.isEmpty ? nil : preferredShape,
            technicalNotes: technicalNotes.isEmpty ? nil : technicalNotes,
            customerTag: customerTag.isEmpty ? nil : customerTag,
            isPhoneMasked: client?.isPhoneMasked,
            birthDay: hasBirthday ? birthDay : nil,
            birthMonth: hasBirthday ? birthMonth : nil,
            birthYear: hasBirthday ? yearParsed : nil,
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
