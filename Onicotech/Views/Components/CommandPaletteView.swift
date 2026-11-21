import SwiftUI
import Observation

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
    
    // Cached data snapshots for global search
    private var clients: [Client] = []
    private var appointments: [Appointment] = []
    private var products: [Product] = []
    private var expenses: [Expense] = []
    private var promotions: [Promotion] = []
    private weak var salonManager: SalonManager?
    
    // Navigation & quick actions
    var onNewAppointment: (() -> Void)?
    var onNewClient: (() -> Void)?
    var onNewSale: (() -> Void)?
    var onNewProduct: (() -> Void)?
    var onNewExpense: (() -> Void)?
    var onToggleTheme: (() -> Void)?
    var onNavigateAppointments: ((String?, String?) -> Void)?
    var onNavigateClients: ((String?, UUID?) -> Void)?
    var onNavigateServices: (() -> Void)?
    var onNavigateProducts: ((Bool, Bool, String?) -> Void)?
    var onNavigateExpenses: ((Bool, String?) -> Void)?
    var onNavigateStatistics: (() -> Void)?
    var onNavigateTaxes: (() -> Void)?
    var onNavigatePromotions: ((String?) -> Void)?
    var onNavigateSettings: ((SettingsSection) -> Void)?
    
    enum SettingsSection {
        case hours, staff, booking, system
    }
    
    func setSalonManager(_ manager: SalonManager) {
        self.salonManager = manager
        rebuildItems()
    }
    
    func updateClients(_ clients: [Client]) {
        self.clients = clients
        rebuildItems()
    }
    
    func updateAppointments(_ appointments: [Appointment]) {
        self.appointments = appointments
        rebuildItems()
    }
    
    func updateProducts(_ products: [Product]) {
        self.products = products
        rebuildItems()
    }
    
    func updateExpenses(_ expenses: [Expense]) {
        self.expenses = expenses
        rebuildItems()
    }
    
    func updatePromotions(_ promotions: [Promotion]) {
        self.promotions = promotions
        rebuildItems()
    }
    
    func loadAllData() async {
        let salonId = salonManager?.selectedSalonId
        let isOwner = salonManager?.isOwner ?? true
        let today = Date()
        let startStr = DateFormatter.iso8601DateOnly.string(from: today)
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today
        let endStr = DateFormatter.iso8601DateOnly.string(from: endDate)
        
        async let fetchedClients: [Client]? = try? APIClient.shared.getClients()
        async let fetchedAppointments: [Appointment]? = try? APIClient.shared.getAppointments(
            startDate: startStr,
            endDate: endStr,
            salonId: salonId
        )
        async let fetchedProducts: [Product]? = try? APIClient.shared.getProducts(salonId: salonId)
        async let fetchedPromotions: [Promotion]? = try? APIClient.shared.getPromotions(salonId: salonId)
        async let fetchedExpenses: [Expense]? = isOwner ? (try? APIClient.shared.getExpenses(salonId: salonId)) : []
        
        if let c = await fetchedClients { clients = c }
        if let a = await fetchedAppointments { appointments = a }
        if let p = await fetchedProducts { products = p }
        if let pr = await fetchedPromotions { promotions = pr }
        if let e = await fetchedExpenses { expenses = e }
        
        rebuildItems()
    }
    
    private func rebuildItems() {
        let isOwner = salonManager?.isOwner ?? true
        var newItems: [CommandPaletteItem] = []
        
        // MARK: - Azioni Rapide
        newItems.append(contentsOf: [
            CommandPaletteItem(
                title: "Nuovo Appuntamento",
                subtitle: "Pianifica un appuntamento a calendario",
                systemImage: "calendar.badge.plus",
                category: .actions
            ) { [weak self] in self?.onNewAppointment?() },
            CommandPaletteItem(
                title: "Nuova Cliente",
                subtitle: "Registra una nuova scheda cliente",
                systemImage: "person.badge.plus",
                category: .actions
            ) { [weak self] in self?.onNewClient?() },
            CommandPaletteItem(
                title: "Nuova Vendita Retail (Cassa)",
                subtitle: "Registra un acquisto prodotti al banco",
                systemImage: "cart.badge.plus",
                category: .actions
            ) { [weak self] in self?.onNewSale?() },
            CommandPaletteItem(
                title: "Nuovo Prodotto a Magazzino",
                subtitle: "Aggiungi articolo, scorta e prezzo vendita",
                systemImage: "shippingbox.fill",
                category: .actions
            ) { [weak self] in self?.onNewProduct?() }
        ])
        
        if isOwner {
            newItems.append(
                CommandPaletteItem(
                    title: "Nuova Spesa / Uscita",
                    subtitle: "Registra spesa operativa, scontrino o fornitura",
                    systemImage: "creditcard.fill",
                    category: .actions
                ) { [weak self] in self?.onNewExpense?() }
            )
        }
        
        // MARK: - Navigazione
        newItems.append(contentsOf: [
            CommandPaletteItem(
                title: "Calendario Appuntamenti",
                subtitle: "Visualizza e pianifica trattamenti",
                systemImage: "calendar",
                category: .navigation
            ) { [weak self] in self?.onNavigateAppointments?(nil, nil) },
            CommandPaletteItem(
                title: "Anagrafica Clienti",
                subtitle: "Elenco clienti, storico e recall",
                systemImage: "person.3",
                category: .navigation
            ) { [weak self] in self?.onNavigateClients?(nil, nil) },
            CommandPaletteItem(
                title: "Listino Servizi & Trattamenti",
                subtitle: "Trattamenti, durate e prezzi",
                systemImage: "scissors",
                category: .navigation
            ) { [weak self] in self?.onNavigateServices?() },
            CommandPaletteItem(
                title: "Magazzino Prodotti & Retail",
                subtitle: "Giacenze, barcode e retail",
                systemImage: "shippingbox",
                category: .navigation
            ) { [weak self] in self?.onNavigateProducts?(false, false, nil) },
            CommandPaletteItem(
                title: "Promozioni & Offerte",
                subtitle: "Gestisci sconti e voucher",
                systemImage: "tag.fill",
                category: .navigation
            ) { [weak self] in self?.onNavigatePromotions?(nil) }
        ])
        
        if isOwner {
            newItems.append(contentsOf: [
                CommandPaletteItem(
                    title: "Spese & Uscite",
                    subtitle: "Registrazione spese operative",
                    systemImage: "creditcard",
                    category: .navigation
                ) { [weak self] in self?.onNavigateExpenses?(false, nil) },
                CommandPaletteItem(
                    title: "Statistiche & Incassi",
                    subtitle: "Fatturato, scontrino medio e trend",
                    systemImage: "chart.bar",
                    category: .navigation
                ) { [weak self] in self?.onNavigateStatistics?() },
                CommandPaletteItem(
                    title: "Fisco & Tasse (Forfettario)",
                    subtitle: "Stima tasse e contributi INPS",
                    systemImage: "eurosign.circle",
                    category: .navigation
                ) { [weak self] in self?.onNavigateTaxes?() },
                CommandPaletteItem(
                    title: "Orari di Apertura",
                    subtitle: "Configura fasce orarie e pause pranzo",
                    systemImage: "clock",
                    category: .navigation
                ) { [weak self] in self?.onNavigateSettings?(.hours) },
                CommandPaletteItem(
                    title: "Team & Collaboratrici",
                    subtitle: "Gestione operatrici e permessi",
                    systemImage: "person.2.badge.key.fill",
                    category: .navigation
                ) { [weak self] in self?.onNavigateSettings?(.staff) },
                CommandPaletteItem(
                    title: "Booking Online",
                    subtitle: "Link pubblico e impostazioni prenotazione",
                    systemImage: "globe",
                    category: .navigation
                ) { [weak self] in self?.onNavigateSettings?(.booking) }
            ])
        }
        
        newItems.append(
            CommandPaletteItem(
                title: "Account & Impostazioni",
                subtitle: "Profilo, sicurezza e sistema",
                systemImage: "gear",
                category: .navigation
            ) { [weak self] in self?.onNavigateSettings?(.system) }
        )
        
        // MARK: - Clienti
        for client in clients.prefix(15) {
            let tagPart = client.customerTag.map { " • Tag: \($0)" } ?? ""
            newItems.append(CommandPaletteItem(
                title: client.fullName,
                subtitle: "📞 \(client.phone ?? "Nessun telefono")\(tagPart)",
                systemImage: "person.circle",
                category: .clients
            ) { [weak self] in
                self?.onNavigateClients?(client.fullName, client.id)
            })
        }
        
        // MARK: - Appuntamenti
        let todayStr = DateFormatter.iso8601DateOnly.string(from: Date())
        let upcoming = appointments
            .filter { $0.date >= todayStr }
            .sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
            .prefix(10)
        
        for appt in upcoming {
            let clientName = appt.client?.fullName ?? "Cliente"
            let services = appt.services?.map(\.name).joined(separator: ", ") ?? "Nessun servizio"
            newItems.append(CommandPaletteItem(
                title: "\(clientName) • \(appt.date) \(appt.startTime)",
                subtitle: "\(services) • \(appt.status?.displayName ?? "Programmato")",
                systemImage: "calendar.badge.clock",
                category: .appointments
            ) { [weak self] in
                self?.onNavigateAppointments?(clientName, appt.date)
            })
        }
        
        // MARK: - Prodotti
        for product in products.prefix(10) {
            let stock = product.totalStock ?? 0
            let stockLabel = stock <= 5 ? " ⚠️ Stock: \(stock)" : " 📦 \(stock)"
            let brandPrefix = product.brand.map { "\($0) • " } ?? ""
            newItems.append(CommandPaletteItem(
                title: product.name,
                subtitle: "\(brandPrefix)€\(String(format: "%.2f", Double(product.price) / 100))\(stockLabel)",
                systemImage: "shippingbox.fill",
                category: .products
            ) { [weak self] in
                self?.onNavigateProducts?(false, false, product.name)
            })
        }
        
        // MARK: - Spese (solo owner)
        if isOwner {
            for expense in expenses.prefix(8) {
                let salonPart = expense.salon.map { " • \($0.name)" } ?? ""
                newItems.append(CommandPaletteItem(
                    title: expense.description,
                    subtitle: "€\(String(format: "%.2f", Double(expense.amount) / 100)) • \(expense.category.displayName)\(salonPart)",
                    systemImage: "creditcard.fill",
                    category: .expenses
                ) { [weak self] in
                    self?.onNavigateExpenses?(false, expense.description)
                })
            }
        }
        
        // MARK: - Promozioni
        for promo in promotions.prefix(8) {
            var validity = ""
            if let start = promo.startDate, let end = promo.endDate {
                let s = DateFormatter.iso8601DateOnly.string(from: start)
                let e = DateFormatter.iso8601DateOnly.string(from: end)
                validity = " (\(s) → \(e))"
            }
            newItems.append(CommandPaletteItem(
                title: promo.name,
                subtitle: "\(promo.description ?? "") • Sconto \(Int(promo.discountPercent))%\(validity)",
                systemImage: "tag.fill",
                category: .promotions
            ) { [weak self] in
                self?.onNavigatePromotions?(promo.name)
            })
        }
        
        items = newItems
    }
    
    var filteredItems: [CommandPaletteItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.matches(searchText: searchText) }
    }
    
    func open() {
        isPresented = true
        searchText = ""
        rebuildItems()
        Task {
            await loadAllData()
        }
    }
    
    func close() {
        isPresented = false
        searchText = ""
    }
    
    func toggle() {
        if isPresented { close() } else { open() }
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
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        state.close()
                    }
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        searchField
                        
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
                    .background(Color.systemBackgroundCompat)
                    
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
                .frame(minWidth: 320, maxWidth: 560, minHeight: 300, maxHeight: 580)
                .background(Color.systemBackgroundCompat)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
                .padding(.horizontal, 16)
            }
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
    
    @ViewBuilder
    private var searchField: some View {
        #if os(iOS)
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
        #else
        TextField("Cerca o Vai a... (⌘K)", text: $state.searchText)
            .focused($isSearchFocused)
            .font(.system(size: 15))
            .onSubmit { executeSelected() }
            .disableAutocorrection(true)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        #endif
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let items = state.filteredItems
        guard !items.isEmpty else {
            if press.key == .escape {
                state.close()
                return .handled
            }
            return .ignored
        }
        
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
        state.close()
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

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let iso8601DateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
    
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
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
