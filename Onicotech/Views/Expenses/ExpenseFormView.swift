import SwiftUI
import Kingfisher
#if canImport(UIKit)
import UIKit
#endif

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    var expense: Expense?
    var onSave: () -> Void
    
    @State private var description = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .other
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var date = Date()
    @State private var isRecurring = false
    @State private var notes = ""
    @State private var isSaving = false
    
    // Photo states
    @State private var showSourcePicker = false
    @State private var showGallery = false
    @State private var showCamera = false
    @State private var pendingImages: [Data] = []
    @State private var existingPhotos: [ExpensePhoto] = []
    @State private var isUploading = false
    #if os(iOS)
    @State private var inputImage: UIImage?
    #else
    @State private var inputImageData: Data?
    #endif
    
    private var isEditing: Bool { expense != nil }
    
    private var amountInCents: Int {
        let cleaned = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned) else { return 0 }
        return Int(value * 100)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Descrizione *", text: $description)
                    
                    HStack {
                        Text("€")
                            .foregroundStyle(.secondary)
                        TextField("Importo *", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
                
                Section("Categoria") {
                    Picker("Categoria", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.iconName).tag(cat)
                        }
                    }
                }
                
                Section("Pagamento") {
                    Picker("Metodo", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.displayName, systemImage: method.iconName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("Spesa Ricorrente Mensile", isOn: $isRecurring)
                }
                
                // Receipt photos
                Section("Ricevuta") {
                    if !existingPhotos.isEmpty || !pendingImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if isUploading {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 80, height: 80)
                                        ProgressView()
                                    }
                                }
                                
                                // Pending images
                                ForEach(pendingImages.indices, id: \.self) { index in
                                    #if os(iOS)
                                    if let uiImage = UIImage(data: pendingImages[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(alignment: .topTrailing) {
                                                Button { pendingImages.remove(at: index) } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.caption)
                                                        .foregroundStyle(.white, .red)
                                                }
                                                .offset(x: 4, y: -4)
                                            }
                                    }
                                    #endif
                                }
                                
                                // Existing photos
                                PhotoHorizontalList(
                                    photos: existingPhotos,
                                    onPhotoDeleted: { photo in
                                        deleteExistingPhoto(photo)
                                    }
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        showSourcePicker = true
                    } label: {
                        Label("Aggiungi Foto Ricevuta", systemImage: "camera")
                    }
                }
                
                Section("Note") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(isEditing ? "Modifica Spesa" : "Nuova Spesa")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Salva" : "Crea") {
                        Task { await save() }
                    }
                    .disabled(description.isEmpty || amountInCents <= 0 || isSaving)
                }
            }
            #if os(iOS)
            .photoSourcePicker(
                showSourcePicker: $showSourcePicker,
                showGallery: $showGallery,
                showCamera: $showCamera,
                selectedImage: $inputImage
            )
            .onChange(of: inputImage) {
                guard let image = inputImage,
                      let data = image.jpegData(compressionQuality: 0.8) else { return }
                pendingImages.append(data)
                inputImage = nil
            }
            #else
            .photoSourcePicker(
                showSourcePicker: $showSourcePicker,
                showGallery: $showGallery,
                showCamera: $showCamera,
                selectedImageData: $inputImageData
            )
            .onChange(of: inputImageData) {
                guard let data = inputImageData else { return }
                pendingImages.append(data)
                inputImageData = nil
            }
            #endif
            .onAppear {
                if let expense {
                    description = expense.description
                    amountText = String(format: "%.2f", Double(expense.amount) / 100.0)
                    category = expense.category
                    paymentMethod = expense.paymentMethod
                    isRecurring = expense.isRecurring
                    notes = expense.notes ?? ""
                    existingPhotos = expense.photos ?? []
                    
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    if let d = f.date(from: expense.date) {
                        date = d
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func save() async {
        isSaving = true
        
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        
        let newExpense = Expense(
            description: description.trimmingCharacters(in: .whitespaces),
            amount: amountInCents,
            category: category,
            paymentMethod: paymentMethod,
            date: f.string(from: date),
            isRecurring: isRecurring,
            notes: notes.isEmpty ? nil : notes
        )
        
        do {
            let savedExpense: Expense
            if let id = expense?.id {
                savedExpense = try await APIClient.shared.updateExpense(id: id, newExpense)
            } else {
                savedExpense = try await APIClient.shared.createExpense(newExpense)
            }
            
            if let expenseId = savedExpense.id, !pendingImages.isEmpty {
                isUploading = true
                for imageData in pendingImages {
                    _ = try await APIClient.shared.uploadExpensePhoto(expenseId: expenseId, image: imageData)
                }
                pendingImages = []
                isUploading = false
            }
            
            onSave()
            dismiss()
        } catch {
            print("Error saving expense: \(error)")
        }
        
        isSaving = false
    }
    
    private func deleteExistingPhoto(_ photo: ExpensePhoto) {
        Task {
            do {
                try await APIClient.shared.deleteExpensePhoto(id: photo.id)
                await MainActor.run {
                    existingPhotos.removeAll { $0.id == photo.id }
                }
            } catch {
                print("Error deleting photo: \(error)")
            }
        }
    }
}
