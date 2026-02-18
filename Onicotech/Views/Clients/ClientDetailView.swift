import SwiftUI

enum AppointmentFilter: String, CaseIterable {
    case upcoming = "Prossimi"
    case past = "Passati"
    case all = "Tutti"
}

struct ClientDetailView: View {
    private let initialClient: Client
    var clientViewModel: ClientViewModel
    
    init(client: Client, clientViewModel: ClientViewModel) {
        self.initialClient = client
        self.clientViewModel = clientViewModel
    }
    
    private var client: Client {
        if let id = initialClient.id,
           let fresh = clientViewModel.clients.first(where: { $0.id == id }) {
            return fresh
        }
        return initialClient
    }
    
    @State private var appointments: [Appointment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFilter: AppointmentFilter = .upcoming
    @State private var showingEditSheet = false
    @State private var photos: [Photo] = []
    @State private var selectedPhoto: Photo?
    @State private var showingAddAppointmentSheet = false
    @State private var selectedAppointment: Appointment?
    @State private var appointmentViewModel = AppointmentViewModel()
    
    private var filteredAppointments: [Appointment] {
        let today = currentDateString()
        switch selectedFilter {
        case .upcoming:
            return appointments
                .filter { $0.date >= today && $0.status != .cancelled }
                .sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
        case .past:
            return appointments
                .filter { $0.date < today }
                .sorted { ($0.date, $0.startTime) > ($1.date, $1.startTime) }
        case .all:
            return appointments
        }
    }
    
    var body: some View {
        List {
            // Client info section
            Section {
                if let phone = client.phone, !phone.isEmpty {
                    HStack {
                        Label("Telefono", systemImage: "phone")
                        Spacer()
                        Link(phone, destination: URL(string: "tel:\(phone)")!)
                            .foregroundStyle(.blue)
                    }
                }
                
                if let email = client.email, !email.isEmpty {
                    HStack {
                        Label("Email", systemImage: "envelope")
                        Spacer()
                        Link(email, destination: URL(string: "mailto:\(email)")!)
                            .foregroundStyle(.blue)
                    }
                }
                
                if let notes = client.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Note", systemImage: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(notes)
                    }
                }
                
                if client.phone == nil && client.email == nil && client.notes == nil {
                    Text("Nessun dettaglio aggiuntivo")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Informazioni")
            }
            
            Section("Galleria") {
                PhotoHorizontalList(photos: photos, onPhotoSelected: { photo in
                    selectedPhoto = photo
                })
            }
            
            // Filter picker + appointments
            Section {
                Picker("Filtro", selection: $selectedFilter) {
                    ForEach(AppointmentFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if filteredAppointments.isEmpty {
                    ContentUnavailableView(
                        emptyMessage,
                        systemImage: "calendar",
                        description: Text(emptyDescription)
                    )
                    .frame(minHeight: 150)
                } else {
                    ForEach(filteredAppointments) { appointment in
                        AppointmentRowCompact(appointment: appointment)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAppointment = appointment
                            }
                    }
                }
            } header: {
                Text("Appuntamenti (\(filteredAppointments.count))")
            }
        }
        .navigationTitle(client.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddAppointmentSheet = true
                    } label: {
                        Label("Nuovo Appuntamento", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Modifica Cliente", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ClientFormView(viewModel: clientViewModel, client: client)
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoGalleryViewer(photos: photos, initialPhoto: photo)
        }
        #else
        .sheet(item: $selectedPhoto) { photo in
            PhotoGalleryViewer(photos: photos, initialPhoto: photo)
        }
        #endif
        .sheet(isPresented: $showingAddAppointmentSheet) {
            Task { await loadAppointments() }
        } content: {
            AppointmentFormView(
                viewModel: appointmentViewModel,
                preselectedClientId: client.id
            )
        }
        .sheet(item: $selectedAppointment) { appointment in
            AppointmentDetailView(appointmentId: appointment.id!, initialAppointment: appointment, viewModel: appointmentViewModel)
        }
        .task {
            await loadAppointments()
            await loadPhotos()
        }
    }
    
    private var emptyMessage: String {
        switch selectedFilter {
        case .upcoming: return "Nessun appuntamento futuro"
        case .past: return "Nessun appuntamento passato"
        case .all: return "Nessun appuntamento"
        }
    }
    
    private var emptyDescription: String {
        switch selectedFilter {
        case .upcoming: return "Non ci sono appuntamenti programmati"
        case .past: return "Nessun appuntamento completato"
        case .all: return "Questo cliente non ha ancora appuntamenti"
        }
    }
    
    private func loadAppointments() async {
        isLoading = true
        do {
            guard let clientId = client.id else { return }
            appointments = try await APIClient.shared.getClientAppointments(clientId: clientId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func loadPhotos() async {
        do {
            guard let clientId = client.id else { return }
            photos = try await APIClient.shared.getClientPhotos(clientId: clientId)
        } catch {
            print("Error loading client photos: \(error)")
        }
    }
    
    private func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

// Compact row for client detail list
struct AppointmentRowCompact: View {
    let appointment: Appointment
    
    var statusColor: Color {
        switch appointment.status {
        case .scheduled: return .blue
        case .rescheduled: return .orange
        case .cancelled: return .red
        case .none: return .gray
        }
    }
    
    var body: some View {
        HStack {
            // Date badge
            VStack(spacing: 2) {
                Text(dayString)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(monthString)
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(appointment.timeRange)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    if let status = appointment.status {
                        Image(systemName: status.iconName)
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }
                    
                }
                if let services = appointment.services, !services.isEmpty {
                    Text(services.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(appointment.formattedTotalPrice)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
    
    private var dayString: String {
        let components = appointment.date.split(separator: "-")
        return components.count == 3 ? String(components[2]) : ""
    }
    
    private var monthString: String {
        let months = ["", "Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic"]
        let components = appointment.date.split(separator: "-")
        guard components.count == 3, let m = Int(components[1]), m >= 1, m <= 12 else { return "" }
        return months[m]
    }
}
