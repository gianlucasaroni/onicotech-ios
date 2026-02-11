import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var appointmentViewModel = AppointmentViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView
                
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
                                        .background(Color(.systemBackground))
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
        }
        .navigationTitle("Dashboard")
        .inlineNavigationTitle()
        .background(Color(.systemGroupedBackground))
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
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
                Text("Benvenuta 👋")
                    .font(.largeTitle)
                    .bold()
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
