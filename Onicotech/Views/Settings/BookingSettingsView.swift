import SwiftUI

struct BookingSettingsView: View {
    @EnvironmentObject var salonManager: SalonManager
    @State private var selectedSalonId: UUID? = nil
    @State private var copiedFeedback = false
    
    private var activeSalon: Salon? {
        if let id = selectedSalonId {
            return salonManager.salons.first(where: { $0.id == id })
        }
        return salonManager.selectedSalon ?? salonManager.defaultSalon
    }
    
    var body: some View {
        Form {
            if salonManager.salons.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nessuna sede configurata",
                        systemImage: "building.2",
                        description: Text("Configura una sede per ottenere il tuo link di prenotazione online.")
                    )
                }
            } else {
                if salonManager.salons.count > 1 {
                    Section("Seleziona Sede") {
                        Picker("Sede Attiva", selection: Binding(
                            get: { activeSalon?.id ?? salonManager.salons.first?.id },
                            set: { selectedSalonId = $0 }
                        )) {
                            ForEach(salonManager.salons) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                    }
                }
                
                if let salon = activeSalon {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(salon.name)
                                    .font(.headline)
                                Spacer()
                                if salon.isDefault {
                                    Text("PREDEFINITA")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .foregroundStyle(Color.accentColor)
                                Text(salon.bookingPath)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text("Indirizzo web: \(salon.bookingURL())")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Button {
                            copyLink(for: salon)
                        } label: {
                            HStack {
                                Label(
                                    copiedFeedback ? "Link Copiato negli Appunti!" : "Copia Link di Prenotazione",
                                    systemImage: copiedFeedback ? "checkmark.circle.fill" : "doc.on.doc"
                                )
                                .foregroundStyle(copiedFeedback ? .green : .accentColor)
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
                        Text("Link di Prenotazione Online")
                    }
                    
                    Section("Come Funziona") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "1.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Condividi il Link")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Inserisci il link nella bio di Instagram, invialo via WhatsApp o mostralo sul tuo sito.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "2.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("La Cliente Sceglie e Prenota")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("La cliente visualizza il tuo listino, seleziona i trattamenti e sceglie data e ora disponibili.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "3.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Appuntamenti Immediati")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Ogni prenotazione entra direttamente nella tua agenda Onicotech senza sovrapposizioni.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Prenotazioni Online")
        .inlineNavigationTitle()
        .onAppear {
            if selectedSalonId == nil {
                selectedSalonId = (salonManager.selectedSalon ?? salonManager.defaultSalon)?.id
            }
        }
    }
    
    private func copyLink(for salon: Salon) {
        let fullUrl = salon.bookingURL()
        #if os(iOS)
        UIPasteboard.general.string = fullUrl
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullUrl, forType: .string)
        #endif
        
        Haptics.play(.success)
        withAnimation {
            copiedFeedback = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                copiedFeedback = false
            }
        }
    }
}
