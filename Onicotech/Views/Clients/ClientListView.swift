import SwiftUI

enum ClientListTab: String, CaseIterable, Identifiable {
    case all = "Tutti"
    case recall = "Da Ricontattare"
    
    var id: String { rawValue }
}

struct ClientListView: View {
    @State private var viewModel = ClientViewModel()
    @State private var selectedTab: ClientListTab = .all
    @State private var selectedDaysThreshold: Int = 21
    @State private var showingAddSheet = false
    @State private var showingAppointmentSheet = false
    @State private var selectedClientForAppointment: Client?
    @State private var showingDeleteAlert = false
    @State private var clientToDelete: Client?
    @State private var searchText = ""
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return viewModel.clients
        } else {
            return viewModel.clients.filter { client in
                client.fullName.localizedCaseInsensitiveContains(searchText) ||
                (client.phone?.contains(searchText) ?? false) ||
                (client.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var filteredRecallClients: [ClientRecall] {
        if searchText.isEmpty {
            return viewModel.recallClients
        } else {
            return viewModel.recallClients.filter { item in
                item.client.fullName.localizedCaseInsensitiveContains(searchText) ||
                (item.client.phone?.contains(searchText) ?? false) ||
                item.lastServices.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Picker
            Picker("Sezione", selection: $selectedTab) {
                Text("Tutti (\(viewModel.clients.count))").tag(ClientListTab.all)
                HStack {
                    Text("Da Ricontattare")
                    if !viewModel.recallClients.isEmpty {
                        Text("(\(viewModel.recallClients.count))")
                    }
                }
                .tag(ClientListTab.recall)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if selectedTab == .recall {
                // Soglia giorni (21, 28, 35)
                HStack(spacing: 8) {
                    Text("Intervallo:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach([21, 28, 35], id: \.self) { days in
                        Button {
                            selectedDaysThreshold = days
                            Task {
                                await viewModel.loadRecallClients(days: days)
                            }
                        } label: {
                            Text("\(days / 7)+ sett (\(days)gg)")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedDaysThreshold == days ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.12))
                                .foregroundStyle(selectedDaysThreshold == days ? Color.orange : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            
            Group {
                if selectedTab == .all {
                    allClientsView
                } else {
                    recallClientsView
                }
            }
        }
        .navigationTitle("Clienti")
        .searchable(text: $searchText, prompt: selectedTab == .all ? "Cerca cliente" : "Cerca cliente o trattamento")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ClientFormView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAppointmentSheet) {
            if let client = selectedClientForAppointment {
                AppointmentFormView(
                    viewModel: AppointmentViewModel(),
                    preselectedClientId: client.id
                )
            }
        }
        .alert("Eliminare il cliente?", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let client = clientToDelete, let id = client.id {
                    Task {
                        _ = await viewModel.deleteClient(id: id)
                        await viewModel.loadRecallClients(days: selectedDaysThreshold)
                    }
                }
            }
        } message: {
            if let client = clientToDelete {
                Text("Vuoi eliminare \(client.fullName)?")
            }
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
        .task {
            await viewModel.loadAll(days: selectedDaysThreshold)
        }
    }
    
    @ViewBuilder
    private var allClientsView: some View {
        if viewModel.isLoading && viewModel.clients.isEmpty {
            ClientListSkeletonView()
        } else if viewModel.clients.isEmpty {
            ContentUnavailableView(
                "Nessun cliente",
                systemImage: "person.slash",
                description: Text("Aggiungi il tuo primo cliente toccando +")
            )
        } else if filteredClients.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List {
                ForEach(filteredClients) { client in
                    NavigationLink {
                        ClientDetailView(client: client, clientViewModel: viewModel)
                    } label: {
                        ClientRowView(client: client)
                            .contextMenu {
                                Button {
                                    selectedClientForAppointment = client
                                    showingAppointmentSheet = true
                                } label: {
                                    Label("Aggiungi Appuntamento", systemImage: "calendar.badge.plus")
                                }
                            }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            clientToDelete = client
                            showingDeleteAlert = true
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadAll(days: selectedDaysThreshold)
            }
        }
    }
    
    @ViewBuilder
    private var recallClientsView: some View {
        if viewModel.isRecallLoading && viewModel.recallClients.isEmpty {
            ClientListSkeletonView()
        } else if viewModel.recallClients.isEmpty {
            ContentUnavailableView(
                "Nessuna cliente da ricontattare",
                systemImage: "checkmark.seal.fill",
                description: Text("Tutte le clienti hanno un appuntamento fissato o hanno svolto un trattamento da meno di \(selectedDaysThreshold) giorni.")
            )
        } else if filteredRecallClients.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List {
                Section {
                    ForEach(filteredRecallClients) { item in
                        NavigationLink {
                            ClientDetailView(client: item.client, clientViewModel: viewModel)
                        } label: {
                            ClientRecallRowView(
                                item: item,
                                onBookAppointment: {
                                    selectedClientForAppointment = item.client
                                    showingAppointmentSheet = true
                                }
                            )
                        }
                    }
                } header: {
                    Text("\(filteredRecallClients.count) clienti da ricontattare (senza appuntamenti futuri)")
                        .font(.caption)
                }
            }
            .refreshable {
                await viewModel.loadRecallClients(days: selectedDaysThreshold)
            }
        }
    }
}

struct ClientRecallRowView: View {
    let item: ClientRecall
    let onBookAppointment: () -> Void
    
    private var tagColor: Color {
        switch (item.client.customerTag ?? "").lowercased() {
        case "vip": return .orange
        case "nuova cliente", "nuova": return .purple
        case "fedele": return .green
        case "super puntuale", "puntuale": return .blue
        case "esigente": return .indigo
        default: return .secondary
        }
    }
    
    private func cleanPhoneNumber(_ phone: String) -> String {
        return phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    private var whatsappURL: URL {
        guard let phone = item.client.phone, !phone.isEmpty else {
            return URL(string: "https://api.whatsapp.com/send")!
        }
        let clean = cleanPhoneNumber(phone)
        let finalPhone = clean.count <= 10 ? "39\(clean)" : clean
        
        let servicesStr = item.lastServices.isEmpty ? "" : " (\(item.lastServices.joined(separator: ", ")))"
        let weeksStr = item.weeksSinceLastAppointment > 1 ? "\(item.weeksSinceLastAppointment) settimane" : "3 settimane"
        
        let msg = "Ciao \(item.client.firstName)! ✨ Sono passate circa \(weeksStr) dal tuo ultimo trattamento unghie\(servicesStr).\nLe tue unghie sono pronte per il refill? Se vuoi fissare il tuo prossimo appuntamento prima che l'agenda si riempia, scrivimi pure qui quando ti farebbe comodo! 💅"
        
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://api.whatsapp.com/send?phone=\(finalPhone)&text=\(encoded)") ?? URL(string: "https://api.whatsapp.com/send?phone=\(finalPhone)")!
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Name, Customer Tag, Elapsed Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.client.fullName)
                            .font(.headline)
                        
                        if let tag = item.client.customerTag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tagColor.opacity(0.15))
                                .foregroundStyle(tagColor)
                                .clipShape(Capsule())
                        }
                        
                        if let bday = item.client.formattedBirthDate {
                            Text("🎂 \(bday)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.12))
                                .foregroundStyle(.pink)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let nailType = item.client.nailType, !nailType.isEmpty {
                        Text(nailType + (item.client.preferredShape.map { " • \($0)" } ?? ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Badge tempo trascorso
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.caption2)
                        Text("\(item.daysSinceLastAppointment) gg fa")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.daysSinceLastAppointment >= 28 ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundStyle(item.daysSinceLastAppointment >= 28 ? Color.red : Color.orange)
                    .clipShape(Capsule())
                    
                    Text("\(item.weeksSinceLastAppointment) sett fa")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Allergie se presenti
            if let allergies = item.client.allergies, !allergies.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Allergie: \(allergies)")
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .clipShape(Capsule())
            }
            
            // Ultimo trattamento
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Ultimo: \(item.lastAppointmentDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !item.lastServices.isEmpty {
                    Text("• " + item.lastServices.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Action Buttons
            HStack(spacing: 8) {
                if let phone = item.client.phone, !phone.isEmpty {
                    if item.client.isPhoneMasked == true {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text("WhatsApp (Protetto)")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Link(destination: whatsappURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "message.fill")
                                    .font(.caption2)
                                Text("WhatsApp Recall")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Button {
                    onBookAppointment()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.caption2)
                        Text("Prenota")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

struct ClientRowView: View {
    let client: Client
    
    private var tagColor: Color {
        switch (client.customerTag ?? "").lowercased() {
        case "vip": return .orange
        case "nuova cliente", "nuova": return .purple
        case "fedele": return .green
        case "super puntuale", "puntuale": return .blue
        case "esigente": return .indigo
        default: return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(client.fullName)
                    .font(.headline)
                
                if let tag = client.customerTag, !tag.isEmpty {
                    Text(tag)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tagColor.opacity(0.15))
                        .foregroundStyle(tagColor)
                        .clipShape(Capsule())
                }
                
                if let bday = client.formattedBirthDate {
                    Text("🎂 \(bday)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pink.opacity(0.12))
                        .foregroundStyle(.pink)
                        .clipShape(Capsule())
                }
            }
            
            if let allergies = client.allergies, !allergies.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(allergies)
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .clipShape(Capsule())
            }
            
            if let nailType = client.nailType, !nailType.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(nailType + (client.preferredShape.map { " • \($0)" } ?? ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let phone = client.phone, !phone.isEmpty {
                Label(phone, systemImage: client.isPhoneMasked == true ? "lock.fill" : "phone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let email = client.email, !email.isEmpty {
                Label(email, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

