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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.fullName)
                .font(.headline)
            
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
