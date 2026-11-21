import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var salonManager: SalonManager
    @State private var viewModel = DashboardViewModel()
    @State private var appointmentViewModel = AppointmentViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.totalClients == 0 && viewModel.nextAppointments.isEmpty {
                DashboardSkeletonView()
            } else {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Next Free Slot Widget
                if let slot = viewModel.nextFreeSlot {
                    NextFreeSlotWidget(slot: slot)
                        .padding(.horizontal)
                }
                
                // Pending Online Bookings Banner
                if viewModel.pendingBookingsCount > 0 {
                    NavigationLink(destination: AppointmentListView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "hourglass.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Prenotazioni Online in Attesa")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Hai \(viewModel.pendingBookingsCount) richiesta/e da approvare")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                
                // Stats Cards
                HStack(spacing: 16) {
                    StatCard(
                        title: "Clienti",
                        value: "\(viewModel.totalClients)",
                        subtitle: "+\(viewModel.newClients) mese",
                        icon: "person.2.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Guadagno",
                        value: viewModel.monthlyEarnings,
                        subtitle: "Mese corrente",
                        icon: "eurosign.circle.fill",
                        color: .green
                    )
                }
                .padding(.horizontal)
                
                // Advanced Stats Banner
                NavigationLink(destination: StatisticsView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Statistiche Avanzate")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Analisi fatturato, top clienti e servizi")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chart.xyaxis.line")
                        .font(.title)
                        .foregroundStyle(.white)
                    }
                    .padding()
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                
                // Next Appointments
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prossimi Appuntamenti")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if viewModel.nextAppointments.isEmpty {
                        ContentUnavailableView(
                            "Nessun appuntamento",
                            systemImage: "calendar",
                            description: Text("Non hai appuntamenti in programma prossimamente.")
                        )
                        .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.nextAppointments) { appointment in
                                NavigationLink(destination: AppointmentDetailView(appointmentId: appointment.id!, initialAppointment: appointment, viewModel: appointmentViewModel)) {
                                    DashboardAppointmentRow(appointment: appointment)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
            } // else
        } // ScrollView
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SalonPickerMenu {
                    Haptics.play(.selection)
                    Task {
                        await viewModel.loadData(salonId: salonManager.selectedSalonId)
                    }
                }
            }
        }
        .background(Color.groupedBackgroundCompat)
        .onChange(of: salonManager.selectedSalon) {
            Task {
                await viewModel.loadData(salonId: salonManager.selectedSalonId)
            }
        }
        .task {
            await viewModel.loadData(salonId: salonManager.selectedSalonId)
        }
        .refreshable {
            Haptics.play(.light)
            await viewModel.loadData(salonId: salonManager.selectedSalonId)
            Haptics.play(.success)
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
    }
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(date: .complete, time: .omitted).capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                if let firstName = authManager.user?.firstName, !firstName.isEmpty {
                    Text("Ciao \(firstName) 👋")
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    Text("Bentornata 👋")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .padding(12)
        .background(Color.systemBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Compact Dashboard Appointment Row

struct DashboardAppointmentRow: View {
    let appointment: Appointment

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    private var statusColor: Color {
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

    private var parsedDate: Date? {
        Self.isoDateFormatter.date(from: appointment.date)
    }

    private var dateLabel: String {
        guard let date = parsedDate else { return appointment.date }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Oggi" }
        if calendar.isDateInTomorrow(date) { return "Domani" }
        return Self.shortDateFormatter.string(from: date).capitalized
    }

    private var isToday: Bool {
        guard let date = parsedDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var subtitleText: String {
        var parts: [String] = []
        if let services = appointment.services, !services.isEmpty {
            parts.append(services.map(\.name).joined(separator: ", "))
        }
        if let staffName = appointment.staffMember?.displayName, !staffName.isEmpty {
            parts.append(staffName)
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(accentColor)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.startTime)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(dateLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isToday ? .purple : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(appointment.client?.fullName ?? "Cliente")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
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

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.systemBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Next Free Slot Widget

struct NextFreeSlotWidget: View {
    let slot: NextFreeSlot
    @State private var showAppointmentForm = false

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let shortDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    private static let weekdayDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Prossimo slot libero")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .textCase(.uppercase)
                        .lineLimit(1)

                    Text(formattedDate)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Haptics.play(.light)
                    showAppointmentForm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text("Prenota")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .sheet(isPresented: $showAppointmentForm) {
                    AppointmentFormView(
                        viewModel: AppointmentViewModel(),
                        preselectedDate: parsedSlotDate,
                        preselectedTime: DateFormatter.timeOnly.date(from: slot.startTime)
                    )
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(slot.startTime)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                if let staffName = slot.staffName, !staffName.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 5) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(staffName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.green.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(Color.systemBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.22), lineWidth: 1)
        )
    }

    private var parsedSlotDate: Date {
        Self.isoDateFormatter.date(from: slot.date) ?? Date()
    }

    private var formattedDate: String {
        let date = parsedSlotDate
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi, \(Self.shortDayMonthFormatter.string(from: date).capitalized)"
        }
        if calendar.isDateInTomorrow(date) {
            return "Domani, \(Self.shortDayMonthFormatter.string(from: date).capitalized)"
        }
        return Self.weekdayDayMonthFormatter.string(from: date).capitalized
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
