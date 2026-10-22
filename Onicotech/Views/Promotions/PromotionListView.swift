import SwiftUI

struct PromotionListView: View {
    @EnvironmentObject var salonManager: SalonManager
    @StateObject private var viewModel = PromotionViewModel()
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var promoToDelete: Promotion?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.promotions.isEmpty {
                ProgressView()
            } else if viewModel.promotions.isEmpty {
                ContentUnavailableView(
                    "Nessuna promozione",
                    systemImage: "tag.slash",
                    description: Text("Crea la tua prima promozione toccando +")
                )
            } else {
                List {
                    ForEach(viewModel.promotions) { promo in
                        NavigationLink {
                            PromotionFormView(viewModel: viewModel, promotionToEdit: promo)
                        } label: {
                            PromotionRowView(promotion: promo)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                promoToDelete = promo
                                showingDeleteAlert = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    Haptics.play(.light)
                    await viewModel.loadPromotions(salonId: salonManager.selectedSalonId)
                    Haptics.play(.success)
                }
            }
        }
        .navigationTitle("Promozioni")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SalonPickerMenu {
                    Haptics.play(.selection)
                    Task { await viewModel.loadPromotions(salonId: salonManager.selectedSalonId) }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.play(.light)
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuova promozione")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PromotionFormView(viewModel: viewModel)
        }
        .alert("Elimina Promozione", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let promo = promoToDelete {
                    Task {
                        let ok = await viewModel.deletePromotion(id: promo.id)
                        if ok { Haptics.play(.warning) }
                    }
                }
            }
        } message: {
            if let promo = promoToDelete {
                Text("Sei sicuro di voler eliminare '\(promo.name)'? Questa azione non può essere annullata.")
            }
        }
        .onChange(of: salonManager.selectedSalon) { _, _ in
            Task { await viewModel.loadPromotions(salonId: salonManager.selectedSalonId) }
        }
        .task {
            await viewModel.loadPromotions(salonId: salonManager.selectedSalonId)
        }
    }
}

struct PromotionRowView: View {
    let promotion: Promotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(promotion.name)
                    .font(.headline)
                if let salon = promotion.salon {
                    SalonBadge(name: salon.name, isDefault: salon.isDefault)
                }
                Spacer()
                if !promotion.active {
                    Text("INATTIVA")
                        .font(.caption)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                Text(String(format: "-%.0f%%", promotion.discountPercent))
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            
            if let desc = promotion.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            HStack {
                if let start = promotion.startDate {
                    Text("Dal: \(start.formatted(date: .numeric, time: .omitted))")
                }
                if let end = promotion.endDate {
                    Text("Al: \(end.formatted(date: .numeric, time: .omitted))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .opacity(promotion.active ? 1.0 : 0.6)
    }
}
