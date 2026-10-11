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
                VStack(alignment: .leading, spacing: 12) {
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
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.nextAppointments) { appointment in
                                NavigationLink(destination: AppointmentDetailView(appointmentId: appointment.id!, initialAppointment: appointment, viewModel: appointmentViewModel)) {
                                    AppointmentRowView(appointment: appointment)
                                        .padding()
                                        .background(Color.systemBackgroundCompat)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SalonPickerMenu {
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
            await viewModel.loadData(salonId: salonManager.selectedSalonId)
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
    }
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let firstName = authManager.user?.firstName {
                     Text("Ciao \(firstName) 👋")
                        .font(.largeTitle)
                        .bold()
                } else {
                     Text("Ciao 👋")
                        .font(.largeTitle)
                        .bold()
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

#Preview {
    NavigationStack {
        DashboardView()
    }
}
