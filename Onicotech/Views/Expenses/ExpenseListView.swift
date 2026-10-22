import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var salonManager: SalonManager
    @State private var expenses: [Expense] = []
    @State private var isLoading = true
    @State private var showingForm = false
    @State private var selectedMonth: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: .now)
    }()
    @State private var selectedCategory: ExpenseCategory?
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirm = false
    
    private var monthlyTotal: Int {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        List {
            // Summary card
            Section {
                VStack(spacing: 8) {
                    Text("Totale Mese")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatting.euros(fromCents: monthlyTotal))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Filters
            Section {
                HStack {
                    Text("Mese")
                    Spacer()
                    MonthPicker(selectedMonth: $selectedMonth)
                }
                
                Picker("Categoria", selection: $selectedCategory) {
                    Text("Tutte").tag(Optional<ExpenseCategory>.none)
                    ForEach(ExpenseCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.iconName).tag(Optional(cat))
                    }
                }
            }
            
            // Expense list
            Section("Spese") {
                if isLoading && expenses.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if expenses.isEmpty {
                    ContentUnavailableView(
                        "Nessuna Spesa",
                        systemImage: "creditcard.and.123",
                        description: Text("Nessuna uscita registrata per il mese e la categoria selezionati.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(expenses) { expense in
                        NavigationLink {
                            ExpenseDetailView(expense: expense, onUpdate: {
                                Task { await loadExpenses() }
                            })
                        } label: {
                            ExpenseRowView(expense: expense)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.play(.warning)
                                expenseToDelete = expense
                                showingDeleteConfirm = true
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Spese")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SalonPickerMenu {
                    Haptics.play(.selection)
                    Task { await loadExpenses() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.play(.light)
                    showingForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuova spesa")
            }
        }
        .sheet(isPresented: $showingForm) {
            ExpenseFormView(expense: nil, onSave: {
                Task { await loadExpenses() }
            })
        }
        .alert("Eliminare questa spesa?", isPresented: $showingDeleteConfirm) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let exp = expenseToDelete, let id = exp.id {
                    Task {
                        do {
                            try await APIClient.shared.deleteExpense(id: id)
                            Haptics.play(.warning)
                            await loadExpenses()
                        } catch {
                            print("Error deleting expense: \(error)")
                        }
                    }
                }
            }
        } message: {
            if let exp = expenseToDelete {
                Text("Vuoi davvero eliminare la spesa \"\(exp.description)\" di \(exp.formattedAmount)?")
            }
        }
        .task { await loadExpenses() }
        .refreshable {
            Haptics.play(.light)
            await loadExpenses()
            Haptics.play(.success)
        }
        .onChange(of: selectedMonth) { _, _ in
            Task { await loadExpenses() }
        }
        .onChange(of: selectedCategory) { _, _ in
            Task { await loadExpenses() }
        }
        .onChange(of: salonManager.selectedSalon) { _, _ in
            Task { await loadExpenses() }
        }
    }
    
    private func loadExpenses() async {
        isLoading = true
        do {
            expenses = try await APIClient.shared.getExpenses(
                month: selectedMonth,
                category: selectedCategory?.rawValue,
                salonId: salonManager.selectedSalonId
            )
        } catch {
            print("Error loading expenses: \(error)")
        }
        isLoading = false
    }
    
    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            let expense = expenses[index]
            guard let id = expense.id else { continue }
            Task {
                do {
                    try await APIClient.shared.deleteExpense(id: id)
                    await loadExpenses()
                } catch {
                    print("Error deleting expense: \(error)")
                }
            }
        }
    }
}

// MARK: - Row

struct ExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.iconName)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(expense.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let salon = expense.salon {
                        SalonBadge(name: salon.name, isDefault: salon.isDefault)
                    }
                }
                HStack(spacing: 4) {
                    Text(expense.category.displayName)
                    if expense.isRecurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                Text(expense.paymentMethod.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Month Picker

struct MonthPicker: View {
    @Binding var selectedMonth: String
    
    private var months: [String] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        var result: [String] = []
        for i in stride(from: 5, through: 0, by: -1) {
            if let date = Calendar.current.date(byAdding: .month, value: -i, to: .now) {
                result.append(f.string(from: date))
            }
        }
        return result
    }
    
    var body: some View {
        Picker("", selection: $selectedMonth) {
            ForEach(months, id: \.self) { m in
                Text(displayMonth(m)).tag(m)
            }
        }
        .pickerStyle(.menu)
    }
    
    private func displayMonth(_ s: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: s) else { return s }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        display.locale = Locale(identifier: "it_IT")
        return display.string(from: date).capitalized
    }
}
