import SwiftUI

struct ProductStockAdjustSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var viewModel: ProductViewModel
    
    let product: Product
    
    @State private var selectedSalonId: UUID
    @State private var actionType: String = "add" // "add", "remove", "set"
    @State private var amountText: String = "1"
    @State private var isSubmitting = false
    
    init(viewModel: ProductViewModel, product: Product, defaultSalonId: UUID?) {
        self.viewModel = viewModel
        self.product = product
        let initialSalonId = defaultSalonId ?? ProductStockAdjustSheet.salonManagerFallback(product: product)
        _selectedSalonId = State(initialValue: initialSalonId)
    }
    
    private static func salonManagerFallback(product: Product) -> UUID {
        product.stocks?.first?.salonId ?? UUID()
    }
    
    var currentQuantity: Int {
        product.stock(for: selectedSalonId)
    }
    
    var resultingQuantity: Int {
        let val = Int(amountText) ?? 0
        switch actionType {
        case "add": return currentQuantity + val
        case "remove": return max(0, currentQuantity - val)
        case "set": return max(0, val)
        default: return currentQuantity
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Prodotto") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if salonManager.salons.count > 1 {
                        Picker("Sede Salone", selection: $selectedSalonId) {
                            ForEach(salonManager.salons) { salon in
                                Text(salon.name).tag(salon.id)
                            }
                        }
                    } else if let onlySalon = salonManager.salons.first {
                        LabeledContent("Sede Salone", value: onlySalon.name)
                    }
                    
                    LabeledContent("Giacenza Attuale", value: "\(currentQuantity) pz")
                }
                
                Section("Operazione Magazzino") {
                    Picker("Tipo Movimento", selection: $actionType) {
                        Text("Carico (+)").tag("add")
                        Text("Scarico (-)").tag("remove")
                        Text("Imposta Esatto (=)").tag("set")
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(actionType == "set" ? "Nuova Giacenza:" : "Quantità:")
                        Spacer()
                        TextField("Quantità", text: $amountText)
                            .numberKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    LabeledContent("Nuova Giacenza Prevista") {
                        Text("\(resultingQuantity) pz")
                            .font(.headline)
                            .foregroundStyle(resultingQuantity <= product.minStockAlert ? .red : .primary)
                    }
                }
            }
            .navigationTitle("Aggiorna Giacenza")
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
                            await submitAdjustment()
                        }
                    }
                    .disabled(isSubmitting || Int(amountText) == nil)
                }
            }
            .onAppear {
                if let salonId = salonManager.selectedSalonId {
                    selectedSalonId = salonId
                } else if let firstSalon = salonManager.salons.first {
                    selectedSalonId = firstSalon.id
                }
            }
        }
    }
    
    private func submitAdjustment() async {
        guard let val = Int(amountText) else { return }
        isSubmitting = true
        
        let success: Bool
        if actionType == "set" {
            success = await viewModel.adjustStock(
                productId: product.id,
                salonId: selectedSalonId,
                quantity: max(0, val)
            )
        } else if actionType == "add" {
            success = await viewModel.adjustStock(
                productId: product.id,
                salonId: selectedSalonId,
                delta: max(1, val)
            )
        } else {
            success = await viewModel.adjustStock(
                productId: product.id,
                salonId: selectedSalonId,
                delta: -max(1, val)
            )
        }
        
        isSubmitting = false
        if success {
            dismiss()
        }
    }
}
