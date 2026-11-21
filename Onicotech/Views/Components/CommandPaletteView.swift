import SwiftUI
import Combine

// MARK: - Command Palette Item

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let category: CommandCategory
    let action: () -> Void
    
    enum CommandCategory: String, CaseIterable {
        case actions = "Azioni rapide"
        case navigation = "Navigazione"
        case clients = "Clienti"
        case appointments = "Appuntamenti"
        case products = "Prodotti"
        case expenses = "Spese"
        case promotions = "Promozioni"
    }
    
    func matches(searchText: String) -> Bool {
        let lower = searchText.lowercased()
        return title.lowercased().contains(lower) ||
               subtitle.lowercased().contains(lower) ||
               systemImage.lowercased().contains(lower) ||
               category.rawValue.lowercased().contains(lower)
    }
}

// MARK: - Command Palette State (Global)

@MainActor
@Observable
final class CommandPaletteState {
    var isPresented = false
    var searchText = ""
    private var items: [CommandPaletteItem] = []
    private var filteredItemsCache: [CommandPaletteItem] = []
    
    // Services
    @ObservationIgnored private var clientVM: ClientViewModel?
    @ObservationIgnored private var appointmentVM: AppointmentViewModel?
    @ObservationIgnored private var productVM: ProductViewModel?
    @ObservationIgnored private var expenseVM: ExpenseViewModel?
    @ObservationIgnored private var promotionVM: PromotionViewModel?
    @ObservationIgnored private var salonManager: SalonManager?
    @ObservationIgnored private var router: AppRouter?
    
    func configure(
        clientVM: ClientViewModel,
        appointmentVM: AppointmentViewModel,
        productVM: ProductViewModel,
        expenseVM: ExpenseViewModel,
        promotionVM: PromotionViewModel,
        salonManager: SalonManager,
        router: AppRouter
    ) {
        self.clientVM = clientVM
        self.appointmentVM = appointmentVM
        self.productVM = productVM
        self.expenseVM = expenseVM
        self.promotionVM = promotionVM
        self.salonManager = salonManager
        self.router = router
        rebuildItems()
    }
    
    private func rebuildItems() {
        guard let salonId = salonManager.selectedSalonId else { return }
        
        var newItems: [CommandPaletteItem] = []
        
        // MARK: - Azioni Rapide
        newItems.append(contentsOf: [
            CommandPaletteItem(
                title: "Nuovo Appuntamento",
                subtitle: "Pianifica un appuntamento a calendario",
                systemImage: "calendar.badge.plus",
                category: .actions
            ) { [weak self] in
                self?.router?.navigateToAppointments(newAppointment: true)
                self?.close()
            },
            CommandPaletteItem(
                title: "Nuova Cliente",
                subtitle: "Registra una nuova scheda cliente",
                systemImage: "person.badge.plus",
                category: .actions
            ) { [weak self] in
                self?.router?.navigateToClients(newClient: true)
                self?.close()
            },
            CommandPaletteItem(
                title: "Nuova Vendita Retail (Cassa)",
                subtitle: "Registra un acquisto prodotti al banco",
                systemImage: "cart.badge.plus",
                category: .actions
            ) { [weak self] in
                self?.router?.navigateToProducts(newSale: true)
                self?.close()
            },
            CommandPaletteItem(
                title: "Nuovo Prodotto a Magazzino",
                subtitle: "Aggiungi articolo, scorta e prezzo vendita",
                systemImage: "shippingbox.fill",
                category: .actions
            ) { [weak self] in
                self?.router?.navigateToProducts(newProduct: true)
                self?.close()
            },
            CommandPaletteItem(
                title: "Nuova Spesa / Uscita",
                subtitle: "Registra spesa operativa, scontrino o fornitura",
                systemImage: "creditcard.fill",
                category: .actions
            ) { [weak self] in
                self?.router?.navigateToExpenses(newExpense: true)
                self?.close()
            },
            CommandPaletteItem(
                title: "Inverti Tema Chiaro / Scuro",
                subtitle: "Alterna istantaneamente la visualizzazione dark mode",
                systemImage: "circle.lefthalf.filled",
                category: .actions
            ) { [weak self] in
                self?.toggleTheme()
                self?.close()
            }
        ])
        
        // MARK: - Navigazione
        newItems.append(contentsOf: [
            CommandPaletteItem(
                title: "Calendario Appuntamenti",
                subtitle: "Visualizza e pianifica trattamenti",
                systemImage: "calendar",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToAppointments(); self?.close() },
            CommandPaletteItem(
                title: "Anagrafica Clienti",
                subtitle: "Elenco clienti, storico e recall",
                systemImage: "person.3",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToClients(); self?.close() },
            CommandPaletteItem(
                title: "Listino Servizi & Trattamenti",
                subtitle: "Trattamenti, durate e prezzi",
                systemImage: "scissors",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToServices(); self?.close() },
            CommandPaletteItem(
                title: "Magazzino Prodotti & Retail",
                subtitle: "Giacenze, barcode e retail",
                systemImage: "shippingbox",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToProducts(); self?.close() },
            CommandPaletteItem(
                title: "Spese & Uscite",
                subtitle: "Registrazione spese operative",
                systemImage: "creditcard",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToExpenses(); self?.close() },
            CommandPaletteItem(
                title: "Statistiche & Incassi",
                subtitle: "Fatturato, scontrino medio e trend",
                systemImage: "chart.bar",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToStatistics(); self?.close() },
            CommandPaletteItem(
                title: "Fisco & Tasse (Forfettario)",
                subtitle: "Stima tasse e contributi INPS",
                systemImage: "eurosign.circle",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToTaxes(); self?.close() },
            CommandPaletteItem(
                title: "Promozioni & Offerte",
                subtitle: "Gestisci sconti e voucher",
                systemImage: "tag.fill",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToPromotions(); self?.close() },
            CommandPaletteItem(
                title: "Orari di Apertura",
                subtitle: "Configura fasce orarie e pause pranzo",
                systemImage: "clock",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToSettings(.hours); self?.close() },
            CommandPaletteItem(
                title: "Team & Collaboratrici",
                subtitle: "Gestione operatrici e permessi",
                systemImage: "person.2.badge.key.fill",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToSettings(.staff); self?.close() },
            CommandPaletteItem(
                title: "Booking Online",
                subtitle: "Link pubblico e impostazioni prenotazione",
                systemImage: "globe",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToSettings(.booking); self?.close() },
            CommandPaletteItem(
                title: "Account & Impostazioni",
                subtitle: "Profilo, sicurezza e sistema",
                systemImage: "gear",
                category: .navigation
            ) { [weak self] in self?.router?.navigateToSettings(.system); self?.close() }
        ])
        
        // MARK: - Clienti (from ClientViewModel)
        if let clients = clientVM?.clients {
            for client in clients.prefix(10) {
                newItems.append(CommandPaletteItem(
                    title: client.fullName,
                    subtitle: "📞 \(client.phone ?? "Nessun telefono")\(client.customerTag.map { " • Tag: \($0)" } ?? "")",
                    systemImage: "person.circle",
                    category: .clients
                ) { [weak self] in
                    self?.router?.navigateToClients(search: client.fullName, clientId: client.id)
                    self?.close()
                })
            }
        }
        
        // MARK: - Appuntamenti (from AppointmentViewModel)
        if let appointments = appointmentVM?.appointments {
            let upcoming = appointments
                .filter { $0.date >= DateFormatter.iso8601DateOnly.string(from: Date()) }
                .sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
                .prefix(10)
            
            for appt in upcoming {
                let clientName = appt.clientName ?? "Cliente"
                let services = appt.services?.map(\.name).joined(separator: ", ") ?? "Nessun servizio"
                newItems.append(CommandPaletteItem(
                    title: "\(clientName) • \(appt.date) \(appt.startTime)",
                    subtitle: "\(services) • \(appt.status?.displayName ?? "Programmato")",
                    systemImage: "calendar.badge.clock",
                    category: .appointments
                ) { [weak self] in
                    self?.router?.navigateToAppointments(search: clientName, date: appt.date)
                    self?.close()
                })
            }
        }
        
        // MARK: - Prodotti (from ProductViewModel)
        if let products = productVM?.products {
            for product in products.prefix(8) {
                let stock = product.stock ?? 0
                let stockLabel = stock <= 5 ? " ⚠️ Stock: \(stock)" : " 📦 \(stock)"
                newItems.append(CommandPaletteItem(
                    title: product.name,
                    subtitle: "\(product.brand.map { "\($0) • " } ?? "")€\(String(format: "%.2f", Double(product.salePrice ?? 0) / 100))\(stockLabel)",
                    systemImage: "shippingbox.fill",
                    category: .products
                ) { [weak self] in
                    self?.router?.navigateToProducts(search: product.name)
                    self?.close()
                })
            }
        }
        
        // MARK: - Spese (from ExpenseViewModel) - solo owner
        if salonManager.activeRole == "owner", let expenses = expenseVM?.expenses {
            for expense in expenses.prefix(5) {
                newItems.append(CommandPaletteItem(
                    title: expense.description,
                    subtitle: "€\(String(format: "%.2f", Double(expense.amount) / 100)) • \(expense.category)\(expense.location.map { " • \($0)" } ?? "")",
                    systemImage: "creditcard.fill",
                    category: .expenses
                ) { [weak self] in
                    self?.router?.navigateToExpenses(search: expense.description)
                    self?.close()
                })
            }
        }
        
        // MARK: - Promozioni (from PromotionViewModel)
        if let promotions = promotionVM?.promotions {
            for promo in promotions.prefix(5) {
                newItems.append(CommandPaletteItem(
                    title: promo.name,
                    subtitle: "\(promo.description ?? "") • Sconto \(Int(promo.discountPercent))%\(promo.validFrom != nil && promo.validTo != nil ? " (\(promo.validFrom!) → \(promo.validTo!))" : "")",
                    systemImage: "tag.fill",
                    category: .promotions
                ) { [weak self] in
                    self?.router?.navigateToPromotions(search: promo.name)
                    self?.close()
                })
            }
        }
        
        items = newItems
        filteredItemsCache = newItems
    }
    
    var filteredItems: [CommandPaletteItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.matches(searchText: searchText) }
    }
    
    func open() {
        isPresented = true
        searchText = ""
    }
    
    func close() {
        isPresented = false
        searchText = ""
    }
    
    func toggle() {
        if isPresented { close() } else { open() }
    }
    
    private func toggleTheme() {
        // Theme toggle is handled by AppAppearanceManager
        if let manager = AppAppearanceManager.shared {
            manager.toggle()
        }
    }
    
    func refresh() {
        rebuildItems()
    }
}

// MARK: - Command Palette View

struct CommandPaletteView: View {
    @Bindable var state: CommandPaletteState
    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex = 0
    
    var body: some View {
        if state.isPresented {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("Cerca o Vai a... (⌘K)", text: $state.searchText)
                        .focused($isSearchFocused)
                        .font(.system(size: 15))
                        .onSubmit { executeSelected() }
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        state.close()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.systemBackground)
                
                Divider()
                
                // Results
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            if state.filteredItems.isEmpty {
                                ContentUnavailableView(
                                    "Nessun risultato",
                                    systemImage: "magnifyingglass",
                                    description: Text("Prova con termini diversi")
                                )
                                .frame(minHeight: 200)
                            } else {
                                ForEach(Array(state.filteredItems.enumerated()), id: \.element.id) { index, item in
                                    CommandPaletteRow(
                                        item: item,
                                        isSelected: index == selectedIndex
                                    ) {
                                        selectedIndex = index
                                        executeItem(item)
                                    }
                                    .id(index)
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
            .frame(minWidth: 440, maxWidth: 560, minHeight: 300, maxHeight: 580)
            .background(Color.systemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
            .onAppear {
                isSearchFocused = true
                selectedIndex = 0
            }
            .onDisappear {
                selectedIndex = 0
            }
            .onKeyPress(keys: [.upArrow, .downArrow, .return, .escape]) { press in
                handleKeyPress(press)
            }
        }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let items = state.filteredItems
        guard !items.isEmpty else { return .ignored }
        
        switch press.key {
        case .upArrow:
            selectedIndex = (selectedIndex - 1 + items.count) % items.count
            return .handled
        case .downArrow:
            selectedIndex = (selectedIndex + 1) % items.count
            return .handled
        case .return:
            if selectedIndex < items.count {
                executeItem(items[selectedIndex])
            }
            return .handled
        case .escape:
            state.close()
            return .handled
        default:
            return .ignored
        }
    }
    
    private func executeSelected() {
        let items = state.filteredItems
        if selectedIndex < items.count {
            executeItem(items[selectedIndex])
        }
    }
    
    private func executeItem(_ item: CommandPaletteItem) {
        item.action()
    }
}

// MARK: - Command Palette Row

struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            Image(systemName: categoryIcon(item.category))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(categoryColor(item.category))
                .frame(width: 20)
            
            // Main icon
            Image(systemName: item.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            // Category badge
            Text(item.category.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(categoryColor(item.category))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(categoryColor(item.category).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            (isSelected || isHovering) 
                ? Color.blue.opacity(0.08) 
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { onTap() }
    }
    
    private func categoryIcon(_ category: CommandPaletteItem.CommandCategory) -> String {
        switch category {
        case .actions: return "bolt.fill"
        case .navigation: return "sidebar.left"
        case .clients: return "person.3.fill"
        case .appointments: return "calendar"
        case .products: return "shippingbox.fill"
        case .expenses: return "creditcard.fill"
        case .promotions: return "tag.fill"
        }
    }
    
    private func categoryColor(_ category: CommandPaletteItem.CommandCategory) -> Color {
        switch category {
        case .actions: return .orange
        case .navigation: return .blue
        case .clients: return .purple
        case .appointments: return .green
        case .products: return .indigo
        case .expenses: return .red
        case .promotions: return .pink
        }
    }
}

// MARK: - App Router Protocol (to be implemented by main app)

@MainActor
protocol AppRouter: AnyObject {
    func navigateToAppointments(newAppointment: Bool, search: String?, date: String?)
    func navigateToClients(newClient: Bool, search: String?, clientId: UUID?)
    func navigateToServices()
    func navigateToProducts(newSale: Bool, newProduct: Bool, search: String?)
    func navigateToExpenses(newExpense: Bool, search: String?)
    func navigateToStatistics()
    func navigateToTaxes()
    func navigateToPromotions(search: String?)
    func navigateToSettings(_ section: SettingsSection)
    
    func navigateToAppointments(newAppointment: Bool)
    func navigateToClients(newClient: Bool)
    func navigateToProducts(newSale: Bool, newProduct: Bool)
    func navigateToExpenses(newExpense: Bool)
}

extension AppRouter {
    func navigateToAppointments(newAppointment: Bool = false, search: String? = nil, date: String? = nil) {
        navigateToAppointments(newAppointment: newAppointment, search: search, date: date)
    }
    func navigateToClients(newClient: Bool = false, search: String? = nil, clientId: UUID? = nil) {
        navigateToClients(newClient: newClient, search: search, clientId: clientId)
    }
    func navigateToProducts(newSale: Bool = false, newProduct: Bool = false, search: String? = nil) {
        navigateToProducts(newSale: newSale, newProduct: newProduct, search: search)
    }
    func navigateToExpenses(newExpense: Bool = false, search: String? = nil) {
        navigateToExpenses(newExpense: newExpense, search: search)
    }
    func navigateToPromotions(search: String? = nil) {
        navigateToPromotions(search: search)
    }
}

enum SettingsSection {
    case hours, staff, booking, system
}

// MARK: - AppAppearanceManager (placeholder for theme)

@MainActor
@Observable
final class AppAppearanceManager {
    static var shared: AppAppearanceManager?
    var isDarkMode = false
    
    func toggle() {
        isDarkMode.toggle()
        // Apply theme
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let iso8601DateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

// MARK: - Preview

#Preview {
    let state = CommandPaletteState()
    state.isPresented = true
    
    return CommandPaletteView(state: state)
        .frame(width: 500, height: 500)
}