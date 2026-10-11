import SwiftUI

struct SalonHoursView: View {
    let salon: Salon
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SalonViewModel()
    
    @State private var hours: [DayHourState] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSavedAlert = false
    
    struct DayHourState: Identifiable {
        var id: Int { dayOfWeek }
        var dayOfWeek: Int // 1=Mon, 2=Tue, ..., 7=Sun
        var dayName: String
        var isOpen: Bool
        var startTime: Date
        var endTime: Date
        var hasBreak: Bool
        var breakStart: Date
        var breakEnd: Date
    }
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Caricamento orari...")
            } else {
                Form {
                    Section {
                        Text("Imposta gli orari di apertura della sede **\(salon.name)** utilizzati per la prenotazione online dei clienti.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach($hours) { $item in
                        Section(header: Text(item.dayName)) {
                            Toggle("Aperto", isOn: $item.isOpen)
                            
                            if item.isOpen {
                                DatePicker("Apertura", selection: $item.startTime, displayedComponents: .hourAndMinute)
                                DatePicker("Chiusura", selection: $item.endTime, displayedComponents: .hourAndMinute)
                                
                                Toggle("Pausa / Chiusura Intermedia", isOn: $item.hasBreak)
                                
                                if item.hasBreak {
                                    DatePicker("Inizio Pausa", selection: $item.breakStart, displayedComponents: .hourAndMinute)
                                    DatePicker("Fine Pausa", selection: $item.breakEnd, displayedComponents: .hourAndMinute)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Orari · \(salon.name)")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Salva") {
                        Task { await save() }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .alert("Orari Salvati", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Gli orari di apertura per la sede '\(salon.name)' sono stati aggiornati.")
        }
        .task {
            await loadHours()
        }
    }
    
    private func defaultTime(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func parseTime(_ str: String, defaultHour: Int) -> Date {
        if let d = timeFormatter.date(from: str) {
            return d
        }
        return defaultTime(hour: defaultHour)
    }
    
    private func loadHours() async {
        isLoading = true
        await viewModel.loadSalonHours(salonId: salon.id)
        
        let dayNames = [
            (1, "Lunedì"),
            (2, "Martedì"),
            (3, "Mercoledì"),
            (4, "Giovedì"),
            (5, "Venerdì"),
            (6, "Sabato"),
            (7, "Domenica")
        ]
        
        var states: [DayHourState] = []
        for (day, name) in dayNames {
            if let found = viewModel.salonHours.first(where: { $0.dayOfWeek == day }) {
                states.append(DayHourState(
                    dayOfWeek: day,
                    dayName: name,
                    isOpen: found.isOpen,
                    startTime: parseTime(found.startTime, defaultHour: 9),
                    endTime: parseTime(found.endTime, defaultHour: 19),
                    hasBreak: found.breakStart != nil && !(found.breakStart?.isEmpty ?? true),
                    breakStart: parseTime(found.breakStart ?? "13:00", defaultHour: 13),
                    breakEnd: parseTime(found.breakEnd ?? "14:00", defaultHour: 14)
                ))
            } else {
                let isWeekend = (day == 7) // Sunday closed by default
                states.append(DayHourState(
                    dayOfWeek: day,
                    dayName: name,
                    isOpen: !isWeekend,
                    startTime: defaultTime(hour: 9),
                    endTime: defaultTime(hour: 19),
                    hasBreak: false,
                    breakStart: defaultTime(hour: 13),
                    breakEnd: defaultTime(hour: 14)
                ))
            }
        }
        
        self.hours = states
        isLoading = false
    }
    
    private func save() async {
        isSaving = true
        
        let items: [BusinessHourItem] = hours.map { state in
            BusinessHourItem(
                id: nil,
                salonId: salon.id,
                dayOfWeek: state.dayOfWeek,
                isOpen: state.isOpen,
                startTime: timeFormatter.string(from: state.startTime),
                endTime: timeFormatter.string(from: state.endTime),
                breakStart: state.hasBreak ? timeFormatter.string(from: state.breakStart) : nil,
                breakEnd: state.hasBreak ? timeFormatter.string(from: state.breakEnd) : nil
            )
        }
        
        let success = await viewModel.saveSalonHours(salonId: salon.id, hours: items)
        isSaving = false
        if success {
            showSavedAlert = true
        }
    }
}
