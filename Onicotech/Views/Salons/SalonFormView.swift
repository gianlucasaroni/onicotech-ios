import SwiftUI

struct SalonFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var viewModel: SalonViewModel
    var salonToEdit: Salon?
    
    @State private var name = ""
    @State private var slug = ""
    @State private var isSlugManuallyEdited = false
    @State private var isCheckingSlug = false
    @State private var isSlugAvailable: Bool? = nil
    @State private var slugCheckTask: Task<Void, Never>? = nil
    
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
                        .onChange(of: name) { _, newName in
                            if !isSlugManuallyEdited {
                                let generated = slugify(newName)
                                slug = generated
                                checkSlugDebounced(generated)
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Slug Link Prenotazione")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                let generated = slugify(name)
                                slug = generated
                                isSlugManuallyEdited = false
                                checkSlugDebounced(generated)
                            } label: {
                                Label("Suggerisci", systemImage: "sparkles")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        
                        HStack(spacing: 4) {
                            Text("/s/")
                                .foregroundStyle(.secondary)
                                .font(.system(.subheadline, design: .monospaced))
                            
                            TextField("slug-sede", text: $slug)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.subheadline, design: .monospaced))
                                .onChange(of: slug) { _, newSlug in
                                    isSlugManuallyEdited = true
                                    checkSlugDebounced(newSlug)
                                }
                            
                            Text("/book")
                                .foregroundStyle(.secondary)
                                .font(.system(.subheadline, design: .monospaced))
                            
                            if isCheckingSlug {
                                ProgressView()
                                    .controlSize(.small)
                            } else if let isAvailable = isSlugAvailable, !slug.isEmpty {
                                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(isAvailable ? .green : .red)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        if let isAvailable = isSlugAvailable, !slug.isEmpty {
                            Text(isAvailable ? "Slug disponibile per il link pubblico" : "Slug già in uso da un'altra sede")
                                .font(.caption2)
                                .foregroundStyle(isAvailable ? .green : .red)
                        } else {
                            Text("Usato nell'indirizzo pubblico per le prenotazioni online")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
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
            .scrollDismissesKeyboard(.interactively)
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
                    slug = salon.slug ?? slugify(salon.name)
                    isSlugManuallyEdited = !(salon.slug == nil || salon.slug?.isEmpty == true)
                    address = salon.address ?? ""
                    city = salon.city ?? ""
                    postalCode = salon.postalCode ?? ""
                    phone = salon.phone ?? ""
                    email = salon.email ?? ""
                    notes = salon.notes ?? ""
                    isDefault = salon.isDefault
                    active = salon.active
                    if !slug.isEmpty {
                        checkSlugDebounced(slug)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func slugify(_ text: String) -> String {
        let lower = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "&", with: "-e-")
        let allowed = CharacterSet.alphanumerics
        var result = ""
        var lastWasHyphen = false
        for scalar in lower.unicodeScalars {
            if allowed.contains(scalar) {
                result.append(Character(scalar))
                lastWasHyphen = false
            } else {
                if !lastWasHyphen && !result.isEmpty {
                    result.append("-")
                    lastWasHyphen = true
                }
            }
        }
        while result.hasSuffix("-") {
            result.removeLast()
        }
        return result
    }
    
    private func checkSlugDebounced(_ rawSlug: String) {
        slugCheckTask?.cancel()
        let trimmed = slugify(rawSlug)
        guard !trimmed.isEmpty else {
            isSlugAvailable = nil
            isCheckingSlug = false
            return
        }
        slugCheckTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await checkSlug(trimmed)
        }
    }
    
    private func checkSlug(_ targetSlug: String) async {
        isCheckingSlug = true
        do {
            let res = try await APIClient.shared.checkSlugAvailability(slug: targetSlug, excludeId: salonToEdit?.id)
            if !Task.isCancelled {
                isSlugAvailable = res.available
            }
        } catch {
            // Non-blocking
        }
        if !Task.isCancelled {
            isCheckingSlug = false
        }
    }
    
    private func save() async {
        guard isValid else { return }
        isSaving = true
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSlug = slugify(slug)
        let slg = trimmedSlug.isEmpty ? nil : trimmedSlug
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
                slug: slg,
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
                slug: slg,
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
            Haptics.play(.success)
            await salonManager.loadSalons()
            dismiss()
        }
    }
}
