import SwiftUI

struct CartItem: Identifiable, Hashable {
    let id = UUID()
    let product: Product
    var quantity: Int
    var unitPrice: Int // in cents
    
    var subtotal: Int {
        quantity * unitPrice
    }
}

struct ProductSaleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var viewModel: ProductViewModel
    
    @State private var clientViewModel = ClientViewModel()
    @State private var selectedSalonId: UUID
    @State private var selectedClientId: UUID? = nil
    @State private var saleDate: Date = Date()
    @State private var paymentMethod: String = "cash"
    @State private var notes: String = ""
    @State private var cartItems: [CartItem] = []
    
    @State private var showingProductPicker = false
    @State private var isSubmitting = false
    
    init(viewModel: ProductViewModel, defaultSalonId: UUID?) {
        self.viewModel = viewModel
        let initialSalon = defaultSalonId ?? UUID()
        _selectedSalonId = State(initialValue: initialSalon)
    }
    
    var totalAmountCents: Int {
        cartItems.reduce(0) { $0 + $1.subtotal }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli Vendita") {
                    if salonManager.salons.count > 1 {
                        Picker("Sede Salone", selection: $selectedSalonId) {
                            ForEach(salonManager.salons) { salon in
                                Text(salon.name).tag(salon.id)
                            }
                        }
                    } else if let onlySalon = salonManager.salons.first {
                        LabeledContent("Sede Salone", value: onlySalon.name)
                    }
                    
                    Picker("Cliente", selection: $selectedClientId) {
                        Text("Anonimo / Al banco").tag(UUID?.none)
                        ForEach(clientViewModel.clients) { client in
                            Text("\(client.firstName) \(client.lastName)").tag(UUID?.some(client.id ?? UUID()))
                        }
                    }
                    
                    DatePicker("Data Vendita", selection: $saleDate, displayedComponents: .date)
                    
                    Picker("Metodo di Pagamento", selection: $paymentMethod) {
                        Text("Contanti").tag("cash")
                        Text("POS / Carta").tag("card")
                        Text("Satispay").tag("satispay")
                        Text("Bonifico").tag("transfer")
                    }
                }
                
                Section {
                    if cartItems.isEmpty {
                        VStack(spacing: 8) {
                            Text("Nessun prodotto nel carrello")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                showingProductPicker = true
                            } label: {
                                Label("Aggiungi Prodotti", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        ForEach($cartItems) { $item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.product.name)
                                        .font(.body.weight(.medium))
                                    Text("\(CurrencyFormatting.euros(fromCents: item.unitPrice)) cad.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Stepper(value: $item.quantity, in: 1...99) {
                                    Text("\(item.quantity) pz")
                                        .font(.callout.monospacedDigit())
                                }
                                
                                Text(CurrencyFormatting.euros(fromCents: item.subtotal))
                                    .font(.callout.weight(.semibold))
                                    .frame(minWidth: 65, alignment: .trailing)
                            }
                        }
                        .onDelete { indexSet in
                            cartItems.remove(atOffsets: indexSet)
                        }
                        
                        Button {
                            showingProductPicker = true
                        } label: {
                            Label("Aggiungi Altro Prodotto", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Prodotti al Banco")
                } footer: {
                    if !cartItems.isEmpty {
                        Text("Scorri verso sinistra su un articolo per rimuoverlo.")
                    }
                }
                
                if !cartItems.isEmpty {
                    Section("Riepilogo Incasso") {
                        HStack {
                            Text("Totale da Incassare")
                                .font(.headline)
                            Spacer()
                            Text(CurrencyFormatting.euros(fromCents: totalAmountCents))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Section("Note Opzionali") {
                    TextField("es. Confezione regalo, scontrino #123...", text: $notes)
                }
            }
            .navigationTitle("Vendita al Banco")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registra Incasso") {
                        Task {
                            await submitSale()
                        }
                    }
                    .disabled(isSubmitting || cartItems.isEmpty)
                }
            }
            .sheet(isPresented: $showingProductPicker) {
                ProductCatalogPickerView(
                    products: viewModel.products.filter { $0.active },
                    salonId: selectedSalonId
                ) { product in
                    addProductToCart(product)
                }
            }
            .task {
                if let salonId = salonManager.selectedSalonId {
                    selectedSalonId = salonId
                } else if let first = salonManager.salons.first {
                    selectedSalonId = first.id
                }
                await clientViewModel.loadClients()
            }
        }
    }
    
    private func addProductToCart(_ product: Product) {
        if let index = cartItems.firstIndex(where: { $0.product.id == product.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.append(CartItem(product: product, quantity: 1, unitPrice: product.price))
        }
    }
    
    private func submitSale() async {
        guard !cartItems.isEmpty else { return }
        isSubmitting = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: saleDate)
        
        let itemRequests = cartItems.map {
            ProductSaleItemRequest(
                productId: $0.product.id,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }
        
        let req = CreateProductSaleRequest(
            salonId: selectedSalonId,
            clientId: selectedClientId,
            appointmentId: nil,
            date: dateString,
            paymentMethod: paymentMethod,
            notes: notes.isEmpty ? nil : notes,
            items: itemRequests
        )
        
        let success = await viewModel.recordSale(req)
        isSubmitting = false
        if success {
            dismiss()
        }
    }
}

struct ProductCatalogPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let products: [Product]
    let salonId: UUID
    let onSelect: (Product) -> Void
    
    @State private var searchText = ""
    
    var filtered: [Product] {
        if searchText.isEmpty { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filtered) { product in
                let currentStock = product.stock(for: salonId)
                Button {
                    onSelect(product)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                Text(product.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let brand = product.brand, !brand.isEmpty {
                                    Text("• \(brand)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(product.formattedPrice)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(currentStock) disp.")
                                .font(.caption2)
                                .foregroundStyle(currentStock <= product.minStockAlert ? .orange : .secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cerca prodotto per nome o brand...")
            .navigationTitle("Seleziona Prodotto")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}
