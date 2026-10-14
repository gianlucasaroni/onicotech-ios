import SwiftUI

struct SalonListView: View {
    @EnvironmentObject var salonManager: SalonManager
    @StateObject private var viewModel = SalonViewModel()
    @State private var showingAddSheet = false
    @State private var salonToEdit: Salon?
    @State private var salonToDelete: Salon?
    @State private var showingDeleteAlert = false
    @State private var copiedSalonId: UUID? = nil
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.salons.isEmpty {
                ProgressView("Caricamento sedi...")
            } else if viewModel.salons.isEmpty {
                ContentUnavailableView(
                    "Nessuna sede configurata",
                    systemImage: "building.2",
                    description: Text("Aggiungi la tua prima sede o salone toccando +")
                )
            } else {
                List {
                    ForEach(viewModel.salons) { salon in
                        NavigationLink(destination: SalonDetailView(viewModel: viewModel, salonId: salon.id, initialSalon: salon)) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(salon.isDefault ? Color.orange.opacity(0.15) : Color.accentColor.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "building.2.fill")
                                        .foregroundStyle(salon.isDefault ? Color.orange : Color.accentColor)
                                        .font(.body)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(salon.name)
                                            .font(.headline)
                                        
                                        if salon.isDefault {
                                            Text("PREDEFINITA")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.yellow.opacity(0.2))
                                                .foregroundStyle(.orange)
                                                .clipShape(Capsule())
                                        }
                                        
                                        if !salon.active {
                                            Text("INATTIVA")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.2))
                                                .foregroundStyle(.secondary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    if !salon.fullAddress.isEmpty {
                                        Text(salon.fullAddress)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    } else if let city = salon.city, !city.isEmpty {
                                        Text(city)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                        Text(salon.bookingPath)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                salonToDelete = salon
                                showingDeleteAlert = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                salonToEdit = salon
                            } label: {
                                Label("Modifica", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            if !salon.isDefault {
                                Button {
                                    Task {
                                        if await viewModel.setDefaultSalon(id: salon.id) {
                                            await salonManager.loadSalons()
                                        }
                                    }
                                } label: {
                                    Label("Predefinita", systemImage: "star")
                                }
                                .tint(.orange)
                            }
                        }
                        .contextMenu {
                            Button {
                                salonToEdit = salon
                            } label: {
                                Label("Modifica Sede", systemImage: "pencil")
                            }
                            
                            Button {
                                copyBookingLink(for: salon)
                            } label: {
                                Label("Copia Link Prenotazione", systemImage: "doc.on.doc")
                            }
                            
                            if !salon.isDefault {
                                Button {
                                    Task {
                                        if await viewModel.setDefaultSalon(id: salon.id) {
                                            await salonManager.loadSalons()
                                        }
                                    }
                                } label: {
                                    Label("Imposta come Predefinita", systemImage: "star")
                                }
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                salonToDelete = salon
                                showingDeleteAlert = true
                            } label: {
                                Label("Elimina Sede", systemImage: "trash")
                            }
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
        .navigationTitle("Sedi e Saloni")
        .inlineNavigationTitle()
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
            SalonFormView(viewModel: viewModel)
        }
        .sheet(item: $salonToEdit) { salon in
            SalonFormView(viewModel: viewModel, salonToEdit: salon)
        }
        .alert("Elimina Sede", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let salon = salonToDelete {
                    Task {
                        if await viewModel.deleteSalon(id: salon.id) {
                            await salonManager.loadSalons()
                        }
                    }
                }
            }
        } message: {
            if let salon = salonToDelete {
                Text("Sei sicuro di voler eliminare la sede '\(salon.name)'?")
            }
        }
        .task {
            await viewModel.loadSalons()
        }
        .refreshable {
            await viewModel.loadSalons()
            await salonManager.loadSalons()
        }
    }
    
    private func copyBookingLink(for salon: Salon) {
        let fullUrl = salon.bookingURL()
        #if os(iOS)
        UIPasteboard.general.string = fullUrl
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullUrl, forType: .string)
        #endif
        
        copiedSalonId = salon.id
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copiedSalonId == salon.id {
                copiedSalonId = nil
            }
        }
    }
}
