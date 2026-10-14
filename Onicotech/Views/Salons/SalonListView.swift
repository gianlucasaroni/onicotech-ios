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
                    description: Text("Aggiungi la tua prima sede/salone toccando +")
                )
            } else {
                List {
                    ForEach(viewModel.salons) { salon in
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(salon.name)
                                                .font(.headline)
                                            
                                            if salon.isDefault {
                                                Text("PREDEFINITA")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.yellow.opacity(0.2))
                                                    .foregroundStyle(.orange)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            if !salon.active {
                                                Text("INATTIVA")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.2))
                                                    .foregroundStyle(.secondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        if !salon.fullAddress.isEmpty {
                                            Label(salon.fullAddress, systemImage: "mappin.circle.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Menu {
                                        Button {
                                            salonToEdit = salon
                                        } label: {
                                            Label("Modifica", systemImage: "pencil")
                                        }
                                        
                                        Button {
                                            copyBookingLink(for: salon)
                                        } label: {
                                            Label("Copia Link Prenotazione", systemImage: "link")
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
                                            Label("Elimina", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                if let phone = salon.phone, !phone.isEmpty {
                                    Label(phone, systemImage: "phone")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Booking link banner
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                    
                                    Text(salon.bookingPath)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Button {
                                        copyBookingLink(for: salon)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: copiedSalonId == salon.id ? "checkmark" : "doc.on.doc")
                                            Text(copiedSalonId == salon.id ? "Copiato" : "Copia link")
                                        }
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Divider()
                                    .padding(.vertical, 2)
                                
                                // Management navigation buttons
                                HStack(spacing: 12) {
                                    NavigationLink(destination: SalonServicesView(salon: salon)) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "scissors")
                                            Text("Listino e Prezzi")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    NavigationLink(destination: SalonHoursView(salon: salon)) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                            Text("Orari Apertura")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
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
