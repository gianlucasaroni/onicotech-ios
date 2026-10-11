import SwiftUI

struct ManagementView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Attività") {
                    NavigationLink(destination: SalonListView()) {
                        Label("Sedi e Saloni", systemImage: "building.2.fill")
                    }
                    
                    NavigationLink(destination: ServiceListView()) {
                        Label("Servizi", systemImage: "scissors")
                    }
                    
                    NavigationLink(destination: ProductListView()) {
                        Label("Prodotti & Magazzino", systemImage: "shippingbox.fill")
                    }
                    
                    NavigationLink(destination: PromotionListView()) {
                        Label("Promozioni", systemImage: "tag.fill")
                    }
                    
                    NavigationLink(destination: ExpenseListView()) {
                        Label("Spese", systemImage: "creditcard.fill")
                    }
                }
                
                Section("Account") {
                    NavigationLink(destination: SettingsView()) {
                        Label("Impostazioni", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Gestione")
        }
    }
}

#Preview {
    ManagementView()
}
