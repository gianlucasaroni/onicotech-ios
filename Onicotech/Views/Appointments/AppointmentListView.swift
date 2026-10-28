import SwiftUI

struct AppointmentSlotContext: Identifiable {
    let id = UUID()
    let date: Date
    let time: Date?
}

struct AppointmentListView: View {
    @EnvironmentObject var salonManager: SalonManager
    @State private var viewModel = AppointmentViewModel()
    @State private var newAppointmentSlot: AppointmentSlotContext?
    @State private var selectedAppointment: Appointment?
    @State private var showingDeleteAlert = false
    @State private var appointmentToDelete: Appointment?
    
    @State private var isCalendarExpanded = true
    @AppStorage("appointmentViewMode") private var storedViewMode: AppointmentViewMode = .week
    
    var body: some View {
        VStack(spacing: 0) {
            // View Mode Segmented Control (Settimana / Giorno)
            Picker("Vista", selection: $viewModel.viewMode) {
                Text("Settimana").tag(AppointmentViewMode.week)
                Text("Giorno").tag(AppointmentViewMode.day)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .background(Color.systemBackgroundCompat)
            
            if viewModel.viewMode == .week {
                // MARK: - Settimana View (Stile Calendario iOS)
                AppointmentWeekView(
                    viewModel: viewModel,
                    onAddAppointment: { date, time in
                        newAppointmentSlot = AppointmentSlotContext(date: date, time: time)
                    }
                )
            } else {
                // MARK: - Giorno View (Vista Calendario e Lista Giornaliera)
                dayViewContent
            }
        }
        .navigationTitle("Appuntamenti")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SalonPickerMenu {
                    Haptics.play(.selection)
                    Task {
                        await viewModel.loadAppointments(salonId: salonManager.selectedSalonId)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.play(.light)
                    newAppointmentSlot = AppointmentSlotContext(date: viewModel.selectedDate, time: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuovo appuntamento")
            }
        }
        .sheet(item: $newAppointmentSlot) { slot in
            AppointmentFormView(
                viewModel: viewModel,
                preselectedDate: slot.date,
                preselectedTime: slot.time
            )
            .id(slot.id)
        }
        .alert("Eliminare l'appuntamento?", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let appt = appointmentToDelete, let id = appt.id {
                    Task {
                        let ok = await viewModel.deleteAppointment(id: id)
                        if ok { Haptics.play(.warning) }
                    }
                }
            }
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
        .onAppear {
            viewModel.viewMode = storedViewMode
        }
        .onChange(of: viewModel.viewMode) { _, newMode in
            storedViewMode = newMode
        }
        .task(id: "\(salonManager.selectedSalonId?.uuidString ?? "")-\(viewModel.viewMode.rawValue)-\(viewModel.viewMode == .week ? viewModel.currentWeekRangeStrings.start : viewModel.selectedDateString)") {
            await viewModel.loadAppointments(salonId: salonManager.selectedSalonId)
        }
        .refreshable {
            Haptics.play(.light)
            await viewModel.loadAppointments(salonId: salonManager.selectedSalonId)
            Haptics.play(.success)
        }
    }
    
    // MARK: - Day View Content
    private var dayViewContent: some View {
        VStack(spacing: 0) {
            // Calendar Section
            VStack(spacing: 0) {
                // Header / Toggle
                HStack {
                    if !isCalendarExpanded {
                        HStack(spacing: 8) {
                            Button {
                                changeDate(by: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Giorno precedente")
                            
                            Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted))
                                .font(.headline)
                                .contentTransition(.numericText())
                            
                            Button {
                                changeDate(by: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Giorno successivo")
                        }
                    } else {
                        Text("Calendario")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button {
                        Haptics.play(.selection)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isCalendarExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isCalendarExpanded ? "chevron.up.circle.fill" : "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(isCalendarExpanded ? "Comprimi calendario" : "Espandi vista calendario")
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                
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
            .background(Color.systemBackgroundCompat)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.top, 4)
            
            Divider()
                .padding(.top, 8)
            
            // Appointments list
            if viewModel.isLoading && viewModel.appointments.isEmpty {
                AppointmentListSkeletonView()
            } else if viewModel.appointments.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Nessun appuntamento",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Non ci sono appuntamenti per questa data e sede selezionata")
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.appointments) { appointment in
                        NavigationLink(destination: AppointmentDetailView(appointmentId: appointment.id ?? UUID(), initialAppointment: appointment, viewModel: viewModel)) {
                            AppointmentRowView(appointment: appointment)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if appointment.status == .pending {
                                Button {
                                    Task {
                                        if let id = appointment.id {
                                            let ok = await viewModel.confirmAppointment(id: id)
                                            if ok { Haptics.play(.success) }
                                        }
                                    }
                                } label: {
                                    Label("Approva", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            } else if appointment.status == .scheduled {
                                Button {
                                    Task {
                                        if let id = appointment.id {
                                            let ok = await viewModel.completeAppointment(id: id)
                                            if ok { Haptics.play(.success) }
                                        }
                                    }
                                } label: {
                                    Label("Completa", systemImage: "checkmark.seal")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.play(.warning)
                                appointmentToDelete = appointment
                                showingDeleteAlert = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            if appointment.status != .cancelled {
                                Button {
                                    Task {
                                        if let id = appointment.id {
                                            let ok = await viewModel.cancelAppointment(id: id)
                                            if ok { Haptics.play(.warning) }
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
    }
    
    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: viewModel.selectedDate) {
            Haptics.play(.selection)
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
        case .pending: return .orange
        case .completed: return .green
        case .rescheduled: return .purple
        case .cancelled: return .red
        case .expired: return .gray
        case .none: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(appointment.timeRange)
                    .font(.headline)
                    .monospacedDigit()
                
                if let salon = appointment.salon {
                    SalonBadge(name: salon.name, isDefault: salon.isDefault)
                }
                
                Spacer()
                
                if let status = appointment.status {
                    Label(status.displayName, systemImage: status.iconName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
            }
            
            if let client = appointment.client {
                HStack(spacing: 6) {
                    Label(client.fullName, systemImage: "person")
                        .font(.subheadline)
                    
                    if let staff = appointment.staffMember {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: staff.color ?? "#9333EA"))
                                .frame(width: 7, height: 7)
                            Text(staff.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    if let tag = client.customerTag, !tag.isEmpty {
                        Text(tag)
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                    
                    if let allergies = client.allergies, !allergies.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(allergies)
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                }
            }
            
            if let services = appointment.services, !services.isEmpty {
                Text(services.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let products = appointment.products, !products.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.caption2)
                    Text("\(products.count) prodott\(products.count == 1 ? "o" : "i") riservat\(products.count == 1 ? "o" : "i")")
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            }
            
            HStack {
                if let notes = appointment.notes, !notes.isEmpty {
                    Label(notes, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if appointment.totalPrice != nil || appointment.finalPrice != nil {
                    Text(appointment.formattedFinalPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
