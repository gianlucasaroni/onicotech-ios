import SwiftUI

struct SalonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var viewModel: SalonViewModel
    let salonId: UUID
    var initialSalon: Salon
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var copiedLinkFeedback = false
    
    var salon: Salon {
        viewModel.salons.first(where: { $0.id == salonId }) ?? initialSalon
    }
    
    var body: some View {
        Form {
            // MARK: - Informazioni Generali
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(salon.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if salon.isDefault {
                            Text("PREDEFINITA")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                        
                        if !salon.active {
                            Text("INATTIVA")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
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
                .padding(.vertical, 4)
                
                if let phone = salon.phone, !phone.isEmpty {
                    if let url = URL(string: "tel://\(phone.filter { "0123456789+".contains($0) })") {
                        Link(destination: url) {
                            HStack {
                                Label(phone, systemImage: "phone.fill")
                                Spacer()
                                Text("Chiama")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label(phone, systemImage: "phone.fill")
                    }
                }
                
                if let email = salon.email, !email.isEmpty {
                    if let url = URL(string: "mailto:\(email)") {
                        Link(destination: url) {
                            HStack {
                                Label(email, systemImage: "envelope.fill")
                                Spacer()
                                Text("Scrivi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label(email, systemImage: "envelope.fill")
                    }
                }
                
                if let notes = salon.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note Interne")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Dati Sede")
            }
            
            // MARK: - Prenotazioni Online
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Indirizzo pubblico per le prenotazioni delle clienti:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(Color.accentColor)
                        
                        Text(salon.bookingPath)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 2)
                
                Button {
                    copyBookingLink()
                } label: {
                    HStack {
                        Label(
                            copiedLinkFeedback ? "Link Copiato negli Appunti!" : "Copia Link Prenotazione",
                            systemImage: copiedLinkFeedback ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .foregroundStyle(copiedLinkFeedback ? .green : .accentColor)
                        
                        Spacer()
                    }
                }
                
                if let url = URL(string: salon.bookingURL()) {
                    ShareLink(item: url) {
                        HStack {
                            Label("Condividi Link...", systemImage: "square.and.arrow.up")
                            Spacer()
                        }
                    }
                    
                    Link(destination: url) {
                        HStack {
                            Label("Apri nel Browser", systemImage: "arrow.up.right.square")
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Prenotazioni Online")
            } footer: {
                Text("Condividi questo link con le clienti su WhatsApp o Instagram per permettere loro di prenotare in autonomia.")
                    .font(.caption2)
            }
            
            // MARK: - Gestione Operativa (Sottopagine)
            Section {
                NavigationLink(destination: SalonServicesView(salon: salon)) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "scissors")
                                .foregroundStyle(Color.accentColor)
                                .font(.subheadline)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Listino e Prezzi")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Configura i servizi attivi e i prezzi dedicati")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink(destination: SalonHoursView(salon: salon)) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "clock")
                                .foregroundStyle(.blue)
                                .font(.subheadline)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Orari di Apertura")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Giorni settimanali, turni di lavoro e pause")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Configurazione Operativa")
            }
            
            // MARK: - Azioni
            Section {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Modifica Dati Sede", systemImage: "pencil")
                }
                
                if !salon.isDefault {
                    Button {
                        Task {
                            if await viewModel.setDefaultSalon(id: salon.id) {
                                await salonManager.loadSalons()
                            }
                        }
                    } label: {
                        Label("Imposta come Sede Predefinita", systemImage: "star")
                    }
                }
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Elimina Sede", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Opzioni")
            }
        }
        .navigationTitle(salon.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Modifica")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            SalonFormView(viewModel: viewModel, salonToEdit: salon)
        }
        .alert("Elimina Sede", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                Task {
                    if await viewModel.deleteSalon(id: salon.id) {
                        await salonManager.loadSalons()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Sei sicuro di voler eliminare la sede '\(salon.name)'? Tutti i dati associati verranno rimossi.")
        }
    }
    
    private func copyBookingLink() {
        let fullUrl = salon.bookingURL()
        #if os(iOS)
        UIPasteboard.general.string = fullUrl
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullUrl, forType: .string)
        #endif
        
        withAnimation {
            copiedLinkFeedback = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                copiedLinkFeedback = false
            }
        }
    }
}
