import SwiftUI

struct AppointmentDetailView: View {
    let appointmentId: UUID
    let initialAppointment: Appointment // Fallback if not found in VM list (e.g. filtered out)
    var viewModel: AppointmentViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // Dynamic lookup for live updates
    private var appointment: Appointment {
        if let live = viewModel.appointments.first(where: { $0.id == appointmentId }) {
            return live
        }
        return initialAppointment
    }
    
    var statusColor: Color {
        switch appointment.status {
        case .scheduled: return .blue
        case .rescheduled: return .orange
        case .cancelled: return .red
        case .none: return .gray
        }
    }
    
    @State private var showEditSheet = false

    var body: some View {
        List {
            // ... (keep sections) ...
            // Status & Time
            Section {
                HStack {
                    Label("Data", systemImage: "calendar")
                    Spacer()
                    Text(formattedDate)
                }
                
                HStack {
                    Label("Orario", systemImage: "clock")
                    Spacer()
                    Text(appointment.timeRange)
                        .monospacedDigit()
                }
                
                if let status = appointment.status {
                    HStack {
                        Label("Stato", systemImage: status.iconName)
                        Spacer()
                        Text(status.displayName)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.1))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Client
            if let client = appointment.client {
                Section("Cliente") {
                    Label(client.fullName, systemImage: "person")
                    
                    if let phone = client.phone, !phone.isEmpty {
                        HStack(spacing: 12) {
                            // Call Button
                            Link(destination: URL(string: "tel:\(cleanPhoneNumber(phone))")!) {
                                Label("Chiama", systemImage: "phone.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            // WhatsApp Button
                            Link(destination: whatsappURL(phone: phone)) {
                                Label("WhatsApp", systemImage: "message.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }
            
            // Services
            if let services = appointment.services, !services.isEmpty {
                Section("Servizi") {
                    ForEach(services) { service in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                    .font(.body)
                                Text(service.formattedDuration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(service.formattedPrice)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Totale")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(appointment.formattedTotalPrice)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Notes
            if let notes = appointment.notes, !notes.isEmpty {
                Section("Note") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("Dettaglio Appuntamento")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifica") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AppointmentFormView(viewModel: viewModel, appointment: appointment)
        }
    }
    
    private var formattedDate: String {
        let months = ["", "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
                      "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"]
        let components = appointment.date.split(separator: "-")
        guard components.count == 3,
              let day = Int(components[2]),
              let month = Int(components[1]),
              month >= 1, month <= 12 else { return appointment.date }
        return "\(day) \(months[month]) \(components[0])"
    }
    
    private func cleanPhoneNumber(_ phone: String) -> String {
        return phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    private func whatsappURL(phone: String) -> URL {
        let clean = cleanPhoneNumber(phone)
        // Assume Italy (+39) if no prefix is present (simple heuristic)
        let finalPhone = clean.count <= 10 ? "39\(clean)" : clean
        
        var msg = "Ciao \(appointment.client?.firstName ?? "Cliente"),\nti ricordo il tuo appuntamento del \(formattedDate) alle \(appointment.startTime)."
        
        if let services = appointment.services, !services.isEmpty {
            msg += "\n\nServizi:"
            for service in services {
                msg += "\n- \(service.name) (\(service.formattedPrice))"
            }
        }
        
        msg += "\n\nA presto!"
        
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(finalPhone)?text=\(encoded)") ?? URL(string: "https://wa.me/\(finalPhone)")!
    }
}
