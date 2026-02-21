import Foundation

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case rent
    case products
    case equipment
    case utilities
    case marketing
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rent: return "Affitto"
        case .products: return "Prodotti"
        case .equipment: return "Attrezzatura"
        case .utilities: return "Utenze"
        case .marketing: return "Marketing"
        case .other: return "Altro"
        }
    }
    
    var iconName: String {
        switch self {
        case .rent: return "house.fill"
        case .products: return "bag.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .utilities: return "bolt.fill"
        case .marketing: return "megaphone.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash
    case card
    case transfer
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cash: return "Contanti"
        case .card: return "Carta"
        case .transfer: return "Bonifico"
        }
    }
    
    var iconName: String {
        switch self {
        case .cash: return "banknote.fill"
        case .card: return "creditcard.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }
}

struct ExpensePhoto: Codable, Identifiable, Hashable {
    var id: UUID
    var expenseId: UUID
    var createdAt: String?
    
    var thumbnailUrl: String {
        "\(APIClient.baseServerURL)/expense-photos/\(id)/thumbnail"
    }
    
    var originalUrl: String {
        "\(APIClient.baseServerURL)/expense-photos/\(id)/view"
    }
}

struct Expense: Codable, Identifiable {
    var id: UUID?
    var description: String
    var amount: Int // cents
    var category: ExpenseCategory
    var paymentMethod: PaymentMethod
    var date: String // "YYYY-MM-DD"
    var isRecurring: Bool = false
    var notes: String?
    var photos: [ExpensePhoto]? = []
    var createdAt: String?
    var updatedAt: String?
    
    var formattedAmount: String {
        CurrencyFormatting.euros(fromCents: amount)
    }
}
