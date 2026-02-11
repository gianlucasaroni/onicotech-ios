import SwiftUI

struct AppointmentListView: View {
    @State private var viewModel = AppointmentViewModel()
    @State private var showingAddSheet = false
    @State private var selectedAppointment: Appointment?
    @State private var showingDeleteAlert = false
    @State private var appointmentToDelete: Appointment?
    
    @State private var isCalendarExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar Section
            VStack(spacing: 0) {
                // Header / Toggle
                HStack {
                    if !isCalendarExpanded {
                        HStack(spacing: 20) {
                            Button {
                                changeDate(by: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                            
                            Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted))
                                .font(.headline)
                                .contentTransition(.numericText())
                            
                            Button {
                                changeDate(by: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        Text("Calendario")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isCalendarExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isCalendarExpanded ? "chevron.up.circle.fill" : "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                if isCalendarExpanded {
                    DatePicker(
                        "Data",
                        selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.top, 8)
            .onChange(of: viewModel.selectedDate) {
                Task { await viewModel.loadAppointments() }
            }
            
            Divider()
            
            // Appointments list
            if viewModel.isLoading && viewModel.appointments.isEmpty {
                Spacer()
                ProgressView("Caricamento...")
                Spacer()
            } else if viewModel.appointments.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Nessun appuntamento",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Non ci sono appuntamenti per questa data")
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.appointments) { appointment in
                        NavigationLink(destination: AppointmentDetailView(appointmentId: appointment.id!, initialAppointment: appointment, viewModel: viewModel)) {
                            AppointmentRowView(appointment: appointment)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                appointmentToDelete = appointment
                                showingDeleteAlert = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            if appointment.status != .cancelled {
                                Button {
                                    Task {
                                        if let id = appointment.id {
                                            _ = await viewModel.cancelAppointment(id: id)
                                        }
                                    }
                                } label: {
                                    Label("Annulla", systemImage: "xmark.circle")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Appuntamenti")
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
            AppointmentFormView(viewModel: viewModel, preselectedDate: viewModel.selectedDate)
        }
        .alert("Eliminare l'appuntamento?", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let appt = appointmentToDelete, let id = appt.id {
                    Task { _ = await viewModel.deleteAppointment(id: id) }
                }
            }
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
        .task {
            await viewModel.loadAppointments()
        }
    }
    
    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: viewModel.selectedDate) {
            withAnimation {
                viewModel.selectedDate = newDate
            }
        }
    }
}

struct AppointmentRowView: View {
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(appointment.timeRange)
                    .font(.headline)
                    .monospacedDigit()
                
                Spacer()
                
                if let status = appointment.status {
                    Label(status.displayName, systemImage: status.iconName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.1))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
            }
            
            if let client = appointment.client {
                Label(client.fullName, systemImage: "person")
                    .font(.subheadline)
            }
            
            if let services = appointment.services, !services.isEmpty {
                Text(services.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                if let notes = appointment.notes, !notes.isEmpty {
                    Label(notes, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}
