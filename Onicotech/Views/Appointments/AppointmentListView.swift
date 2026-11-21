import SwiftUI

struct AppointmentSlotContext: Identifiable {
    let id = UUID()
    let date: Date
    let time: Date?
}

struct AppointmentListView: View {
    @EnvironmentObject var salonManager: SalonManager
    @Environment(\.commandPaletteState) private var commandPaletteState
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
            configureCommandPalette()
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
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
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
    
    private func configureCommandPalette() {
        commandPaletteState?.setSalonManager(salonManager)
        commandPaletteState?.updateAppointments(viewModel.appointments)
        
        commandPaletteState?.onNewAppointment = {
            newAppointmentSlot = AppointmentSlotContext(date: viewModel.selectedDate, time: nil)
        }
        
        commandPaletteState?.onNavigateAppointments = { _, date in
            if let date = date, let parsed = DateFormatter.iso8601DateOnly.date(from: date) {
                viewModel.selectedDate = parsed
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

    private var accentColor: Color {
        if let hex = appointment.staffMember?.color, !hex.isEmpty {
            return Color(hex: hex)
        }
        return statusColor
    }

    private var subtitleText: String {
        var parts: [String] = []
        if let services = appointment.services, !services.isEmpty {
            parts.append(services.map(\.name).joined(separator: ", "))
        }
        if let staffName = appointment.staffMember?.displayName, !staffName.isEmpty {
            parts.append(staffName)
        }
        if let salonName = appointment.salon?.name, !salonName.isEmpty, appointment.salon?.isDefault == false {
            parts.append(salonName)
        }
        return parts.joined(separator: " • ")
    }

    private var hasExtraMeta: Bool {
        let hasProducts = !(appointment.products?.isEmpty ?? true)
        let hasNotes = !(appointment.notes?.isEmpty ?? true)
        return hasProducts || hasNotes
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Capsule()
                .fill(accentColor)
                .frame(width: 3, height: 34)

            // Compact time column
            VStack(alignment: .leading, spacing: 1) {
                Text(appointment.startTime)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let endTime = appointment.endTime, !endTime.isEmpty {
                    Text(endTime)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 46, alignment: .leading)

            // Client + Services + optional compact notes/products
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(appointment.client?.fullName ?? "Cliente")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if let tag = appointment.client?.customerTag, !tag.isEmpty {
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                    
                    if let allergies = appointment.client?.allergies, !allergies.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                
                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if hasExtraMeta {
                    HStack(spacing: 6) {
                        if let products = appointment.products, !products.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 9))
                                Text("\(products.count) prod.")
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(.blue)
                            .fixedSize()
                        }
                        
                        if let notes = appointment.notes, !notes.isEmpty {
                            Label(notes, systemImage: "note.text")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing price & compact status
            VStack(alignment: .trailing, spacing: 2) {
                if appointment.totalPrice != nil || appointment.finalPrice != nil {
                    Text(appointment.formattedFinalPrice)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                if let status = appointment.status {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(status.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(statusColor)
                            .lineLimit(1)
                    }
                }
            }
            .fixedSize()
        }
        .padding(.vertical, 2)
    }
}
