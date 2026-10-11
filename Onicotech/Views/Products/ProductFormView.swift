import SwiftUI

struct ProductFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var viewModel: ProductViewModel
    
    var productToEdit: Product?
    
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var category: String = productCategories.first ?? "Oli Cuticole"
    @State private var barcode: String = ""
    @State private var priceEurosText: String = "12.00"
    @State private var costEurosText: String = "5.00"
    @State private var minStockAlertText: String = "3"
    @State private var initialStockMap: [UUID: String] = [:]
    @State private var isSubmitting = false
    
    var isEditing: Bool {
        productToEdit != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dati Prodotto") {
                    TextField("Nome Prodotto (es. Olio Cuticole Mandorla)", text: $name)
                    TextField("Brand / Marchio (opzionale)", text: $brand)
                    
                    Picker("Categoria", selection: $category) {
                        ForEach(productCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    TextField("Codice a Barre / SKU", text: $barcode)
                }
                
                Section("Prezzi & Margini (€)") {
                    HStack {
                        Text("Prezzo Vendita al Pubblico")
                        Spacer()
                        TextField("0.00", text: $priceEurosText)
                            .decimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Costo Acquisto Fornitore")
                        Spacer()
                        TextField("0.00", text: $costEurosText)
                            .decimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let priceVal = Double(priceEurosText.replacingOccurrences(of: ",", with: ".")),
                       let costVal = Double(costEurosText.replacingOccurrences(of: ",", with: ".")),
                       priceVal > 0 {
                        let marginEuro = priceVal - costVal
                        let marginPercent = (marginEuro / priceVal) * 100.0
                        HStack {
                            Text("Margine Stimato")
                            Spacer()
                            Text(String(format: "+%.2f € (%.0f%%)", marginEuro, marginPercent))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(marginPercent > 40 ? .green : .blue)
                        }
                    }
                }
                
                Section("Scorte & Avvisi") {
                    HStack {
                        Text("Soglia Minima Avviso Sottoscorta")
                        Spacer()
                        TextField("3", text: $minStockAlertText)
                            .numberKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("pz")
                            .foregroundStyle(.secondary)
                    }
                    Text("Quando la scorta del salone scende a o sotto questo valore, apparirà un avviso arancione.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !isEditing && !salonManager.salons.isEmpty {
                    Section("Giacenze Iniziali per Sede") {
                        ForEach(salonManager.salons) { salon in
                            HStack {
                                Text(salon.name)
                                Spacer()
                                TextField("0", text: Binding(
                                    get: { initialStockMap[salon.id] ?? "0" },
                                    set: { initialStockMap[salon.id] = $0 }
                                ))
                                .numberKeyboard()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                Text("pz")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica Prodotto" : "Nuovo Prodotto")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task {
                            await submitForm()
                        }
                    }
                    .disabled(isSubmitting || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let p = productToEdit {
                    name = p.name
                    brand = p.brand ?? ""
                    category = p.category
                    barcode = p.barcode ?? ""
                    priceEurosText = String(format: "%.2f", Double(p.price) / 100.0)
                    costEurosText = String(format: "%.2f", Double(p.cost) / 100.0)
                    minStockAlertText = "\(p.minStockAlert)"
                } else {
                    for salon in salonManager.salons {
                        initialStockMap[salon.id] = "0"
                    }
                }
            }
        }
    }
    
    private func submitForm() async {
        isSubmitting = true
        
        let priceDouble = Double(priceEurosText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let costDouble = Double(costEurosText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let priceCents = Int(round(priceDouble * 100))
        let costCents = Int(round(costDouble * 100))
        let minAlert = Int(minStockAlertText) ?? 3
        
        if let p = productToEdit {
            let req = UpdateProductRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: brand.isEmpty ? nil : brand,
                category: category,
                barcode: barcode.isEmpty ? nil : barcode,
                price: priceCents,
                cost: costCents,
                minStockAlert: minAlert,
                active: p.active
            )
            let success = await viewModel.updateProduct(id: p.id, req)
            isSubmitting = false
            if success {
                dismiss()
            }
        } else {
            var stocks: [String: Int] = [:]
            for (salonId, qtyStr) in initialStockMap {
                if let q = Int(qtyStr), q > 0 {
                    stocks[salonId.uuidString] = q
                }
            }
            
            let req = CreateProductRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: brand.isEmpty ? nil : brand,
                category: category,
                barcode: barcode.isEmpty ? nil : barcode,
                price: priceCents,
                cost: costCents,
                minStockAlert: minAlert,
                active: true,
                initialStocks: stocks.isEmpty ? nil : stocks
            )
            
            let success = await viewModel.createProduct(req, salonId: salonManager.selectedSalonId)
            isSubmitting = false
            if success {
                dismiss()
            }
        }
    }
}
