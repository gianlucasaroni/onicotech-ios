import SwiftUI
internal import EventKit

struct LocalCalendarSettingsView: View {
    @ObservedObject var calendarManager = CalendarManager.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Abilita Sincronizzazione Locale", isOn: $calendarManager.isSyncEnabled)
                    .onChange(of: calendarManager.isSyncEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await calendarManager.requestAccess()
                                if !granted {
                                    calendarManager.isSyncEnabled = false
                                }
                            }
                        }
                    }
            } header: {
                Text("Stato Integrazione")
            } footer: {
                Text("Sincronizza automaticamente gli appuntamenti presi su Onicotech con l'app nativa Calendario di iOS.")
                    .font(.caption2)
            }
            
            if calendarManager.isSyncEnabled {
                Section {
                    if calendarManager.predefinedCalendars.isEmpty {
                        Text("Nessun calendario scrivibile trovato sul dispositivo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Calendario", selection: $calendarManager.selectedCalendarId) {
                            ForEach(calendarManager.predefinedCalendars, id: \.calendarIdentifier) { calendar in
                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 8, height: 8)
                                    Text(calendar.title)
                                }
                                .tag(calendar.calendarIdentifier)
                            }
                        }
                    }
                } header: {
                    Text("Calendario di Destinazione")
                } footer: {
                    Text("Gli appuntamenti creati o modificati verranno inseriti in questo calendario.")
                        .font(.caption2)
                }
            }
            
            Section("Informazioni sulla Privacy") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Accesso Locale", systemImage: "lock.shield.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Onicotech legge e scrive esclusivamente nel calendario selezionato. Nessun altro dato personale o evento privato viene condiviso con terze parti.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Calendario Locale (EventKit)")
        .inlineNavigationTitle()
        .onAppear {
            if calendarManager.isSyncEnabled {
                Task { let _ = await calendarManager.requestAccess() }
            }
        }
    }
}
