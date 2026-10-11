import SwiftUI

struct ClientListView: View {
    @State private var viewModel = ClientViewModel()
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
    
    var body: some View {
        Group {
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
                    await viewModel.loadClients()
                }
            }
        }
        .navigationTitle("Clienti")
        .searchable(text: $searchText, prompt: "Cerca cliente")
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
            await viewModel.loadClients()
        }
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
                Label(phone, systemImage: "phone")
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
