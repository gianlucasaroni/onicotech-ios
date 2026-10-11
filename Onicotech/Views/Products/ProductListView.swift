import SwiftUI

struct ProductListView: View {
    @StateObject private var viewModel = ProductViewModel()
    @EnvironmentObject var salonManager: SalonManager
    
    @State private var selectedTab = 0 // 0: Catalogo & Giacenze, 1: Vendite al Banco
    @State private var showingAddProductSheet = false
    @State private var productToEdit: Product?
    @State private var productForStockAdjust: Product?
    @State private var showingSaleSheet = false
    @State private var productToDelete: Product?
    @State private var showingDeleteProductAlert = false
    @State private var saleToDelete: ProductSale?
    @State private var showingDeleteSaleAlert = false
    
    var activeSalonId: UUID? {
        salonManager.selectedSalonId
    }
    
    // KPIs
    var totalPieces: Int {
        viewModel.products.reduce(0) { $0 + $1.stock(for: activeSalonId) }
    }
    
    var lowStockCount: Int {
        viewModel.products.filter { $0.stock(for: activeSalonId) <= $0.minStockAlert }.count
    }
    
    var totalSalesRevenueCents: Int {
        viewModel.sales.reduce(0) { $0 + $1.totalPrice }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Picker
            Picker("Sezione", selection: $selectedTab) {
                Text("Catalogo & Scorte").tag(0)
                Text("Vendite al Banco").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
            
            if selectedTab == 0 {
                catalogView
            } else {
                salesView
            }
        }
        .navigationTitle("Prodotti & Magazzino")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selectedTab == 0 {
                    Button {
                        showingAddProductSheet = true
                    } label: {
                        Label("Nuovo Prodotto", systemImage: "plus")
                    }
                } else {
                    Button {
                        showingSaleSheet = true
                    } label: {
                        Label("Nuova Vendita", systemImage: "cart.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProductSheet) {
            ProductFormView(viewModel: viewModel)
        }
        .sheet(item: $productToEdit) { product in
            ProductFormView(viewModel: viewModel, productToEdit: product)
        }
        .sheet(item: $productForStockAdjust) { product in
            ProductStockAdjustSheet(
                viewModel: viewModel,
                product: product,
                defaultSalonId: activeSalonId
            )
        }
        .sheet(isPresented: $showingSaleSheet) {
            ProductSaleFormView(
                viewModel: viewModel,
                defaultSalonId: activeSalonId
            )
        }
        .alert("Eliminare il prodotto?", isPresented: $showingDeleteProductAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let p = productToDelete {
                    Task { _ = await viewModel.deleteProduct(id: p.id) }
                }
            }
        } message: {
            if let p = productToDelete {
                Text("Vuoi davvero eliminare \"\(p.name)\"? L'operazione rimuoverà anche lo storico delle giacenze.")
            }
        }
        .alert("Annullare la vendita?", isPresented: $showingDeleteSaleAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Annulla Vendita", role: .destructive) {
                if let s = saleToDelete {
                    Task { _ = await viewModel.deleteSale(id: s.id, salonId: activeSalonId) }
                }
            }
        } message: {
            if let s = saleToDelete {
                Text("Vuoi stornare la vendita di \(s.formattedTotalPrice)? La giacenza dei prodotti verrà ripristinata in magazzino.")
            }
        }
        .task(id: activeSalonId) {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - Catalog Tab
    private var catalogView: some View {
        VStack(spacing: 0) {
            // KPI Summary Row
            HStack(spacing: 12) {
                kpiCard(
                    title: "Referenze",
                    value: "\(viewModel.products.count)",
                    icon: "shippingbox.fill",
                    color: .blue
                )
                kpiCard(
                    title: "Pezzi Disp.",
                    value: "\(totalPieces) pz",
                    icon: "archivebox.fill",
                    color: .green
                )
                kpiCard(
                    title: "Sottoscorta",
                    value: "\(lowStockCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: lowStockCount > 0 ? .orange : .secondary
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Search & Category Filter
            categoryFilterScroll
            
            if viewModel.isLoading && viewModel.products.isEmpty {
                ProgressView("Caricamento catalogo...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredProducts.isEmpty {
                ContentUnavailableView(
                    "Nessun prodotto trovato",
                    systemImage: "tray",
                    description: Text("Aggiungi nuovi prodotti toccando + o modifica i filtri di ricerca.")
                )
            } else {
                List {
                    ForEach(viewModel.filteredProducts) { product in
                        ProductRowView(
                            product: product,
                            activeSalonId: activeSalonId,
                            onEdit: {
                                productToEdit = product
                            },
                            onAdjustStock: {
                                productForStockAdjust = product
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                productToDelete = product
                                showingDeleteProductAlert = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                productToEdit = product
                            } label: {
                                Label("Modifica", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                productForStockAdjust = product
                            } label: {
                                Label("Giacenza", systemImage: "slider.horizontal.2.square")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: "Cerca per nome, marca o barcode...")
            }
        }
    }
    
    // MARK: - Sales Tab
    private var salesView: some View {
        VStack(spacing: 0) {
            // KPI Banner for Sales
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Totale Vendite Banco")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatting.euros(fromCents: totalSalesRevenueCents))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button {
                    showingSaleSheet = true
                } label: {
                    Label("Vendi al Banco", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            
            if viewModel.isLoading && viewModel.sales.isEmpty {
                ProgressView("Caricamento vendite...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sales.isEmpty {
                ContentUnavailableView(
                    "Nessuna vendita registrata",
                    systemImage: "cart",
                    description: Text("Registra una vendita rapida al banco toccando 'Vendi al Banco'.")
                )
            } else {
                List {
                    ForEach(viewModel.sales) { sale in
                        ProductSaleRowView(sale: sale)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    saleToDelete = sale
                                    showingDeleteSaleAlert = true
                                } label: {
                                    Label("Storna", systemImage: "arrow.uturn.backward")
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var categoryFilterScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Tutte", isSelected: viewModel.selectedCategory == nil || viewModel.selectedCategory == "Tutte") {
                    viewModel.selectedCategory = nil
                }
                
                ForEach(productCategories, id: \.self) { cat in
                    categoryChip(title: cat, isSelected: viewModel.selectedCategory == cat) {
                        viewModel.selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
    
    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func loadData() async {
        await viewModel.loadProducts(salonId: activeSalonId)
        await viewModel.loadSales(salonId: activeSalonId)
    }
}

// MARK: - Product Row View
struct ProductRowView: View {
    let product: Product
    let activeSalonId: UUID?
    let onEdit: () -> Void
    let onAdjustStock: () -> Void
    
    var stockCount: Int {
        product.stock(for: activeSalonId)
    }
    
    var isLowStock: Bool {
        stockCount <= product.minStockAlert
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(product.name)
                        .font(.body.weight(.semibold))
                    if !product.active {
                        Text("Inattivo")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    Text(product.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let brand = product.brand, !brand.isEmpty {
                        Text("• \(brand)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(product.formattedPrice)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    if let margin = product.marginPercent {
                        Text(String(format: "Margine %.0f%%", margin))
                            .font(.caption2)
                            .foregroundStyle(margin > 40 ? .green : .blue)
                    }
                }
            }
            
            Spacer()
            
            // Stock badge & quick button
            Button(action: onAdjustStock) {
                VStack(spacing: 2) {
                    Text("\(stockCount)")
                        .font(.headline.weight(.bold))
                    Text("pz")
                        .font(.caption2)
                }
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 6)
                .background(isLowStock ? Color.orange.opacity(0.15) : Color.green.opacity(0.12))
                .foregroundStyle(isLowStock ? Color.orange : Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isLowStock ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Product Sale Row View
struct ProductSaleRowView: View {
    let sale: ProductSale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(sale.clientName ?? "Cliente al banco")
                            .font(.body.weight(.semibold))
                        
                        Text(sale.paymentMethodDisplay)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text("\(sale.salonName) • \(sale.date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(sale.formattedTotalPrice)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)
            }
            
            // Items summary
            VStack(alignment: .leading, spacing: 2) {
                ForEach(sale.items) { item in
                    HStack {
                        Text("• \(item.quantity)x \(item.productName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.formattedSubtotal)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 2)
            
            if let notes = sale.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}
