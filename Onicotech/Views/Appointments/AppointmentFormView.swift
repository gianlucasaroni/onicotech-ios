import SwiftUI
import Foundation

struct AppointmentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @EnvironmentObject var authManager: AuthenticationManager
    var viewModel: AppointmentViewModel
    
    var appointment: Appointment?
    var preselectedClientId: UUID? = nil
    var preselectedDate: Date? = nil
    var preselectedTime: Date? = nil
    
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var selectedClientId: UUID?
    @State private var selectedSalonId: UUID?
    @State private var selectedStaffMemberId: UUID?
    @State private var selectedServiceIds: Set<UUID> = []
    @State private var notes = ""
    @State private var status: AppointmentStatus = .scheduled
    @State private var isSaving = false
    
    // Client Search State
    @State private var clientSearchText = ""
    @State private var showingClientPickerSheet = false
    
    // Data sources
    @State private var clients: [Client] = []
    @State private var services: [Service] = []
    @State private var promotions: [Promotion] = []
    @State private var staffMembers: [SalonMember] = []
    @State private var selectedPromotionId: UUID?
    @State private var isLoadingData = true
    
    init(
        viewModel: AppointmentViewModel,
        appointment: Appointment? = nil,
        preselectedClientId: UUID? = nil,
        preselectedDate: Date? = nil,
        preselectedTime: Date? = nil
    ) {
        self.viewModel = viewModel
        self.appointment = appointment
        self.preselectedClientId = preselectedClientId
        self.preselectedDate = preselectedDate
        self.preselectedTime = preselectedTime
        
        let initialDate = preselectedDate ?? Date()
        let initialTime = preselectedTime ?? Date()
        _date = State(initialValue: initialDate)
        _startTime = State(initialValue: initialTime)
    }
    
    private var isEditing: Bool { appointment != nil }
    
    private var isValid: Bool {
        selectedClientId != nil && !selectedServiceIds.isEmpty
    }
    
    private var activePractitioners: [SalonMember] {
        staffMembers.filter { $0.active && $0.isPractitioner }
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
    
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
                        
                        if salonManager.salons.count > 1 {
                            Section("Sede") {
                                Picker("Sede", selection: $selectedSalonId) {
                                    Text("Predefinita / Non specificata").tag(nil as UUID?)
                                    ForEach(salonManager.salons) { salon in
                                        Text(salon.name + (salon.isDefault ? " (Predefinita)" : "")).tag(salon.id as UUID?)
                                    }
                                }
                            }
                        }
                        
                        if activePractitioners.count > 1 {
                            Section("Operatrice") {
                                Picker("Assegna a", selection: $selectedStaffMemberId) {
                                    Text("Nessuna / Salone").tag(nil as UUID?)
                                    ForEach(activePractitioners) { staff in
                                        Text(staff.displayName).tag(staff.id as UUID?)
                                    }
                                }
                            }
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
                                if let selectedClientId, let client = clients.first(where: { $0.id == selectedClientId }) {
                                    // Selected client card
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.14))
                                                .frame(width: 36, height: 36)
                                            Text(client.initials)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(client.fullName)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            if let phone = client.phone, !phone.isEmpty {
                                                Text(phone)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button("Cambia") {
                                            showingClientPickerSheet = true
                                        }
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.blue)
                                        .buttonStyle(.borderless)
                                        
                                        Button {
                                            self.selectedClientId = nil
                                            self.clientSearchText = ""
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body)
                                                .foregroundStyle(.secondary.opacity(0.7))
                                        }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel("Rimuovi cliente selezionato")
                                    }
                                    .padding(.vertical, 2)
                                } else {
                                    // Search Input row
                                    HStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                        
                                        TextField("Cerca cliente per nome o telefono...", text: $clientSearchText)
                                            .textInputAutocapitalization(.words)
                                            .autocorrectionDisabled()
                                        
                                        if !clientSearchText.isEmpty {
                                            Button {
                                                clientSearchText = ""
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary.opacity(0.7))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    
                                    // Filtered results dropdown
                                    if !clientSearchText.isEmpty {
                                        let matches = filteredInlineClients
                                        if matches.isEmpty {
                                            Text("Nessun cliente corrisponde a \"\(clientSearchText)\"")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(.vertical, 2)
                                        } else {
                                            ForEach(matches.prefix(5)) { client in
                                                Button {
                                                    Haptics.play(.selection)
                                                    selectedClientId = client.id
                                                    clientSearchText = ""
                                                } label: {
                                                    HStack(spacing: 10) {
                                                        ZStack {
                                                            Circle()
                                                                .fill(Color.blue.opacity(0.12))
                                                                .frame(width: 30, height: 30)
                                                            Text(client.initials)
                                                                .font(.system(size: 11, weight: .bold))
                                                                .foregroundStyle(.blue)
                                                        }
                                                        
                                                        VStack(alignment: .leading, spacing: 1) {
                                                            Text(client.fullName)
                                                                .font(.subheadline.weight(.medium))
                                                                .foregroundStyle(.primary)
                                                            if let phone = client.phone, !phone.isEmpty {
                                                                Text(phone)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.secondary)
                                                            }
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        Image(systemName: "plus.circle")
                                                            .font(.subheadline)
                                                            .foregroundStyle(.blue)
                                                    }
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.vertical, 2)
                                            }
                                            
                                            if matches.count > 5 {
                                                Button {
                                                    showingClientPickerSheet = true
                                                } label: {
                                                    HStack {
                                                        Text("Vedi tutti i \(matches.count) risultati...")
                                                            .font(.caption.bold())
                                                            .foregroundStyle(.blue)
                                                        Spacer()
                                                        Image(systemName: "chevron.right")
                                                            .font(.caption2)
                                                            .foregroundStyle(.blue)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    } else {
                                        // Browse all button
                                        Button {
                                            showingClientPickerSheet = true
                                        } label: {
                                            HStack {
                                                Text("Sfoglia tutti i clienti (\(clients.count))")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.blue)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(.vertical, 2)
                                        }
                                        .buttonStyle(.plain)
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
                    .onChange(of: selectedSalonId) { _, newSalonId in
                        Task {
                            if let newSalonId {
                                staffMembers = (try? await APIClient.shared.getSalonStaff(salonId: newSalonId)) ?? []
                            } else {
                                staffMembers = []
                            }
                            if let staffId = selectedStaffMemberId, !staffMembers.contains(where: { $0.id == staffId }) {
                                selectedStaffMemberId = nil
                            }
                            if !isEditing {
                                assignDefaultStaffMember()
                            }
                        }
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
            .scrollDismissesKeyboard(.interactively)
            .alert("Errore", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Si è verificato un errore sconosciuto")
            }
            .task {
                await loadFormData()
            }
            .sheet(isPresented: $showingClientPickerSheet) {
                ClientPickerSheet(clients: clients, selectedClientId: $selectedClientId)
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func loadFormData() async {
        isLoadingData = true
        
        if salonManager.salons.isEmpty {
            await salonManager.loadSalons()
        }
        
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
            let df = Self.dateFormatter
            let timeF = Self.timeFormatter
            if let d = df.date(from: appointment.date) { date = d }
            if let t = timeF.date(from: appointment.startTime) { startTime = t }
            selectedClientId = appointment.clientId
            selectedSalonId = appointment.salonId
            selectedStaffMemberId = appointment.staffMemberId ?? appointment.staffMember?.id
            if let svcIds = appointment.services?.compactMap(\.id) {
                selectedServiceIds = Set(svcIds)
            }
            notes = appointment.notes ?? ""
            status = appointment.status ?? .scheduled
            selectedPromotionId = appointment.promotionId
        } else {
            if salonManager.salons.count == 1 {
                selectedSalonId = salonManager.salons.first?.id
            } else {
                selectedSalonId = salonManager.selectedSalonId ?? salonManager.defaultSalon?.id ?? salonManager.salons.first?.id
            }
            selectedStaffMemberId = nil
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
            if let preselectedTime {
                startTime = preselectedTime
            }
        }
        
        if let salonId = appointment?.salonId ?? selectedSalonId {
            staffMembers = (try? await APIClient.shared.getSalonStaff(salonId: salonId)) ?? []
        }
        
        // Auto-assign practitioner for new appointments
        if !isEditing {
            assignDefaultStaffMember()
        }
        
        isLoadingData = false
    }
    
    private func assignDefaultStaffMember() {
        let practitioners = activePractitioners
        
        // 1. Se c'è una sola operatrice, imposta lei come default
        if practitioners.count == 1, let single = practitioners.first {
            selectedStaffMemberId = single.id
            return
        }
        
        guard let user = authManager.user else { return }
        let currentUserId = user.id
        
        // 2. Se ci sono più operatrici: imposta di default l'utente loggato (per ID)
        if let match = practitioners.first(where: { $0.userId == currentUserId }) {
            selectedStaffMemberId = match.id
            return
        }
        
        // 3. Oppure per corrispondenza nome/cognome
        let userFullName = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
        if let match = practitioners.first(where: { staff in
            let staffName = staff.displayName.trimmingCharacters(in: .whitespaces)
            return staffName.localizedCaseInsensitiveCompare(userFullName) == .orderedSame ||
                   (!user.firstName.isEmpty && staffName.localizedCaseInsensitiveContains(user.firstName))
        }) {
            selectedStaffMemberId = match.id
            return
        }
    }
    
    private var filteredInlineClients: [Client] {
        let q = clientSearchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return clients.filter { client in
            client.fullName.localizedCaseInsensitiveContains(q) ||
            (client.phone?.localizedCaseInsensitiveContains(q) ?? false) ||
            (client.email?.localizedCaseInsensitiveContains(q) ?? false)
        }
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
        
        let dateStr = Self.dateFormatter.string(from: date)
        let timeStr = Self.timeFormatter.string(from: startTime)
        let serviceIdArray = Array(selectedServiceIds)
        
        let success: Bool
        if let id = appointment?.id {
            let request = UpdateAppointmentRequest(
                date: dateStr,
                startTime: timeStr,
                clientId: clientId,
                salonId: selectedSalonId,
                staffMemberId: selectedStaffMemberId,
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
                salonId: selectedSalonId,
                staffMemberId: selectedStaffMemberId,
                serviceIds: serviceIdArray,
                notes: notes.isEmpty ? nil : notes,
                promotionId: selectedPromotionId
            )
            success = await viewModel.createAppointment(request: request)
        }
        
        isSaving = false
        if success {
            Haptics.play(.success)
            dismiss()
        }
    }
    
    private func calculateDiscount(total: Int) -> Int {
        guard let promoId = selectedPromotionId,
              let promo = promotions.first(where: { $0.id == promoId }) else { return 0 }
        return Int(Double(total) * promo.discountPercent / 100.0)
    }
}

// MARK: - Searchable Client Picker Sheet
struct ClientPickerSheet: View {
    let clients: [Client]
    @Binding var selectedClientId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredClients: [Client] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return clients
        }
        return clients.filter { client in
            client.fullName.localizedCaseInsensitiveContains(query) ||
            (client.phone?.localizedCaseInsensitiveContains(query) ?? false) ||
            (client.email?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredClients) { client in
                    Button {
                        Haptics.play(.selection)
                        selectedClientId = client.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.14))
                                    .frame(width: 38, height: 38)
                                Text(client.initials)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.fullName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                
                                if let phone = client.phone, !phone.isEmpty {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedClientId == client.id {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Seleziona Cliente")
            .inlineNavigationTitle()
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Cerca per nome, telefono o email..."
            )
            .overlay {
                if filteredClients.isEmpty && !clients.isEmpty {
                    ContentUnavailableView(
                        "Nessun cliente trovato",
                        systemImage: "magnifyingglass",
                        description: Text("Nessun cliente corrisponde a \"\(searchText)\"")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}
    

