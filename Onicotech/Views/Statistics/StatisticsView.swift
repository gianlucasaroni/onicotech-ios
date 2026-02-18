import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var viewModel = StatisticsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView("Caricamento statistiche...")
                        .padding(.top, 50)
                } else if let stats = viewModel.stats, !stats.isEmpty {
                    // Revenue Chart
                    if let revenue = stats.monthlyRevenue, !revenue.isEmpty {
                        ChartCard(title: "Andamento Fatturato (12 Mesi)") {
                            Chart(revenue) { item in
                                BarMark(
                                    x: .value("Mese", item.monthName),
                                    y: .value("Fatturato", item.revenue / 100.0)
                                )
                                .foregroundStyle(Color.green.gradient)
                            }
                            .frame(height: 200)
                        }
                    }
                    
                    // Top Services
                    if let services = stats.topServices, !services.isEmpty {
                        ChartCard(title: "Top Servizi") {
                            Chart(services) { service in
                                SectorMark(
                                    angle: .value("Utilizzo", service.usageCount),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("Nome", service.name))
                            }
                            .frame(height: 200)
                        }
                    }
                    
                    // Top Spenders
                    if let spenders = stats.topSpenders, !spenders.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Top Clienti")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(spenders) { spender in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(spender.fullName)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                    Text(spender.formattedSpend)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                }
                                .padding()
                                .background(Color.secondaryGroupedBackgroundCompat)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Flop Spenders (Meno Spendenti)
                    if let flops = stats.flopSpenders, !flops.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Clienti Meno Spendenti")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(flops) { spender in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(spender.fullName)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(spender.formattedSpend)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                }
                                .padding()
                                .background(Color.secondaryGroupedBackgroundCompat)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Flop Services (Meno Richiesti)
                    if let flopServices = stats.flopServices, !flopServices.isEmpty {
                         ChartCard(title: "Servizi Meno Richiesti") {
                            Chart(flopServices) { service in
                                BarMark(
                                    x: .value("Utilizzo", service.usageCount),
                                    y: .value("Servizio", service.name)
                                )
                                .foregroundStyle(.orange.gradient)
                            }
                            .frame(height: 200)
                        }
                    }
                    
                    // Unreliable Clients (Indecisi)
                    if let unreliable = stats.unreliableClients, !unreliable.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Clienti \"Indecisi\"")
                                    .font(.headline)
                                Spacer()
                                Text("Cancellazioni/Riprogramm.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(unreliable) { client in
                                HStack {
                                    Text(client.fullName)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(client.count)")
                                        .fontWeight(.bold)
                                        .foregroundStyle(.red)
                                        .frame(width: 30, height: 30)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .padding()
                                .background(Color.secondaryGroupedBackgroundCompat)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Nessun dato", systemImage: "chart.bar.xaxis")
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Statistiche Avanzate")
        .background(Color.groupedBackgroundCompat)
        .task {
            await viewModel.loadStats()
        }
        .refreshable {
            await viewModel.loadStats()
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(Color.secondaryGroupedBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
