import SwiftUI

struct ServiceListView: View {
    @State private var viewModel = ServiceViewModel()
    @State private var showingAddSheet = false
    @State private var selectedService: Service?
    @State private var showingDeleteAlert = false
    @State private var serviceToDelete: Service?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.services.isEmpty {
                ProgressView("Caricamento...")
            } else if viewModel.services.isEmpty {
                ContentUnavailableView(
                    "Nessun servizio",
                    systemImage: "sparkles",
                    description: Text("Aggiungi il tuo primo servizio toccando +")
                )
            } else {
                List {
                    ForEach(viewModel.services) { service in
                        ServiceRowView(service: service) {
                            Task { await viewModel.toggleActive(service: service) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedService = service
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                serviceToDelete = service
                                showingDeleteAlert = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadServices()
                }
            }
        }
        .navigationTitle("Servizi")
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
            ServiceFormView(viewModel: viewModel)
        }
        .sheet(item: $selectedService) { service in
            ServiceFormView(viewModel: viewModel, service: service)
        }
        .alert("Eliminare il servizio?", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let service = serviceToDelete, let id = service.id {
                    Task { _ = await viewModel.deleteService(id: id) }
                }
            }
        } message: {
            if let service = serviceToDelete {
                Text("Vuoi eliminare \"\(service.name)\"?")
            }
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
        .task {
            await viewModel.loadServices()
        }
    }
}

struct ServiceRowView: View {
    let service: Service
    var onToggleActive: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.headline)
                        .foregroundStyle(service.active ? .primary : .secondary)
                    
                    if let desc = service.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button {
                    onToggleActive()
                } label: {
                    Image(systemName: service.active ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(service.active ? .green : .gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                Label(service.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(service.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
        .opacity(service.active ? 1.0 : 0.6)
    }
}
