import SwiftUI
import Combine

@MainActor
class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var sales: [ProductSale] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Filters
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var showLowStockOnly = false
    
    var filteredProducts: [Product] {
        products.filter { product in
            let matchesSearch = searchText.isEmpty ||
                product.name.localizedCaseInsensitiveContains(searchText) ||
                (product.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (product.barcode?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesCategory = selectedCategory == nil || selectedCategory == "Tutte" || product.category == selectedCategory
            
            let matchesLowStock = !showLowStockOnly || product.isLowStock(for: nil)
            
            return matchesSearch && matchesCategory && matchesLowStock
        }
    }
    
    func loadProducts(salonId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await APIClient.shared.getProducts(
                salonId: salonId,
                search: searchText.isEmpty ? nil : searchText,
                category: (selectedCategory == nil || selectedCategory == "Tutte") ? nil : selectedCategory,
                lowStock: showLowStockOnly ? true : nil
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func loadSales(salonId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            sales = try await APIClient.shared.getProductSales(salonId: salonId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func createProduct(_ req: CreateProductRequest, salonId: UUID? = nil) async -> Bool {
        isLoading = true
        do {
            let created = try await APIClient.shared.createProduct(req)
            products.insert(created, at: 0)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    func updateProduct(id: UUID, _ req: UpdateProductRequest) async -> Bool {
        isLoading = true
        do {
            let updated = try await APIClient.shared.updateProduct(id: id, req)
            if let index = products.firstIndex(where: { $0.id == id }) {
                products[index] = updated
            }
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    func deleteProduct(id: UUID) async -> Bool {
        do {
            try await APIClient.shared.deleteProduct(id: id)
            products.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func adjustStock(productId: UUID, salonId: UUID, delta: Int? = nil, quantity: Int? = nil) async -> Bool {
        do {
            let updatedStock = try await APIClient.shared.adjustStock(
                productId: productId,
                salonId: salonId,
                delta: delta,
                quantity: quantity
            )
            
            // Update local product stock
            if let pIndex = products.firstIndex(where: { $0.id == productId }) {
                var p = products[pIndex]
                var stocks = p.stocks ?? []
                if let sIndex = stocks.firstIndex(where: { $0.salonId == salonId }) {
                    stocks[sIndex] = updatedStock
                } else {
                    stocks.append(updatedStock)
                }
                p.stocks = stocks
                p.totalStock = stocks.reduce(0) { $0 + $1.quantity }
                products[pIndex] = p
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func recordSale(_ req: CreateProductSaleRequest) async -> Bool {
        isLoading = true
        do {
            let sale = try await APIClient.shared.createProductSale(req)
            sales.insert(sale, at: 0)
            
            // Reload products to get updated stock counts
            await loadProducts(salonId: req.salonId)
            
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    func deleteSale(id: UUID, salonId: UUID? = nil) async -> Bool {
        do {
            try await APIClient.shared.deleteProductSale(id: id)
            sales.removeAll { $0.id == id }
            // Reload products as stock was returned
            await loadProducts(salonId: salonId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}
