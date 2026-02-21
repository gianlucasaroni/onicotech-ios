import SwiftUI
import Kingfisher

struct ExpenseDetailView: View {
    let expense: Expense
    var onUpdate: () -> Void
    
    @State private var showEditSheet = false
    @State private var selectedPhoto: ExpensePhoto?
    
    var body: some View {
        List {
            // Amount & Date
            Section {
                HStack {
                    Label("Importo", systemImage: "eurosign.circle.fill")
                    Spacer()
                    Text(expense.formattedAmount)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
                
                HStack {
                    Label("Data", systemImage: "calendar")
                    Spacer()
                    Text(formattedDate)
                }
            }
            
            // Category & Payment
            Section {
                HStack {
                    Label("Categoria", systemImage: expense.category.iconName)
                    Spacer()
                    Text(expense.category.displayName)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("Pagamento", systemImage: expense.paymentMethod.iconName)
                    Spacer()
                    Text(expense.paymentMethod.displayName)
                        .foregroundStyle(.secondary)
                }
                
                if expense.isRecurring {
                    Label("Spesa Ricorrente Mensile", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                }
            }
            
            // Photos
            if let photos = expense.photos, !photos.isEmpty {
                Section("Ricevuta") {
                    PhotoHorizontalList(
                        photos: photos,
                        size: 100,
                        onPhotoSelected: { photo in
                            selectedPhoto = photo
                        }
                    )
                }
            }
            
            // Notes
            if let notes = expense.notes, !notes.isEmpty {
                Section("Note") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(expense.description)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifica") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ExpenseFormView(expense: expense, onSave: onUpdate)
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullscreenPhotoViewer(photos: expense.photos ?? [], initialPhoto: photo, title: "Ricevuta")
        }
        #else
        .sheet(item: $selectedPhoto) { photo in
            FullscreenPhotoViewer(photos: expense.photos ?? [], initialPhoto: photo, title: "Ricevuta")
        }
        #endif
    }
    
    private var formattedDate: String {
        DateFormatting.italianDate(from: expense.date)
    }
}
