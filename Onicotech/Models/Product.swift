import Foundation

let productCategories = [
    "Oli Cuticole",
    "Creme Mani & Corpo",
    "Lime & Buffer",
    "Trattamenti Rinforzanti",
    "Kit Cura a Casa",
    "Accessori",
    "Altro"
]

struct ProductStock: Codable, Identifiable, Hashable {
    var id: UUID
    var productId: UUID
    var salonId: UUID
    var salonName: String?
    var quantity: Int
}

struct Product: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var brand: String?
    var category: String
    var barcode: String?
    var price: Int // In cents
    var cost: Int // In cents
    var minStockAlert: Int
    var active: Bool
    var showInOnlineBooking: Bool?
    var stocks: [ProductStock]?
    var totalStock: Int?
    var createdAt: String?
    var updatedAt: String?
    
    var formattedPrice: String {
        CurrencyFormatting.euros(fromCents: price)
    }
    
    var formattedCost: String {
        CurrencyFormatting.euros(fromCents: cost)
    }
    
    var marginPercent: Double? {
        guard price > 0, cost > 0 else { return nil }
        return Double(price - cost) / Double(price) * 100.0
    }
    
    func stock(for salonId: UUID?) -> Int {
        guard let salonId else {
            return totalStock ?? (stocks?.reduce(0) { $0 + $1.quantity } ?? 0)
        }
        return stocks?.first(where: { $0.salonId == salonId })?.quantity ?? 0
    }
    
    func isLowStock(for salonId: UUID?) -> Bool {
        let currentStock = stock(for: salonId)
        return currentStock <= minStockAlert
    }
}

struct CreateProductRequest: Codable {
    var name: String
    var brand: String?
    var category: String
    var barcode: String?
    var price: Int
    var cost: Int
    var minStockAlert: Int
    var active: Bool
    var showInOnlineBooking: Bool?
    var initialStocks: [String: Int]? // salonId -> qty
}

struct UpdateProductRequest: Codable {
    var name: String
    var brand: String?
    var category: String
    var barcode: String?
    var price: Int
    var cost: Int
    var minStockAlert: Int
    var showInOnlineBooking: Bool?
    var active: Bool?
}

struct AdjustStockRequest: Codable {
    var salonId: UUID
    var delta: Int?
    var quantity: Int?
}

struct ProductSaleItem: Codable, Identifiable, Hashable {
    var id: UUID
    var productId: UUID
    var productName: String
    var quantity: Int
    var unitPrice: Int // cents
    var subtotal: Int // cents
    
    var formattedUnitPrice: String {
        CurrencyFormatting.euros(fromCents: unitPrice)
    }
    
    var formattedSubtotal: String {
        CurrencyFormatting.euros(fromCents: subtotal)
    }
}

struct ProductSale: Codable, Identifiable, Hashable {
    var id: UUID
    var salonId: UUID
    var salonName: String
    var clientId: UUID?
    var clientName: String?
    var appointmentId: UUID?
    var date: String
    var paymentMethod: String
    var totalPrice: Int // cents
    var notes: String?
    var items: [ProductSaleItem]
    var createdAt: String
    
    var formattedTotalPrice: String {
        CurrencyFormatting.euros(fromCents: totalPrice)
    }
    
    var paymentMethodDisplay: String {
        switch paymentMethod {
        case "cash": return "Contanti"
        case "card": return "POS / Carta"
        case "satispay": return "Satispay"
        case "transfer": return "Bonifico"
        default: return paymentMethod.capitalized
        }
    }
}

struct ProductSaleItemRequest: Codable {
    var productId: UUID
    var quantity: Int
    var unitPrice: Int?
}

struct CreateProductSaleRequest: Codable {
    var salonId: UUID
    var clientId: UUID?
    var appointmentId: UUID?
    var date: String
    var paymentMethod: String
    var notes: String?
    var items: [ProductSaleItemRequest]
}
