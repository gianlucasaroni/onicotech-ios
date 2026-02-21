import SwiftUI
internal import EventKit

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var calendarManager = CalendarManager.shared
    @State private var showingCacheAlert = false
    @State private var cacheAlertMessage = ""
    @State private var isLoading = false
    @State private var showingLogoutAlert = false
    
    var body: some View {
        Form {
            Section("Sincronizzazione Calendario") {
                Toggle("Abilita Sincronizzazione", isOn: $calendarManager.isSyncEnabled)
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
                
                if calendarManager.isSyncEnabled {
                    Picker("Calendario", selection: $calendarManager.selectedCalendarId) {
                        if calendarManager.predefinedCalendars.isEmpty {
                            Text("Nessun calendario trovato").tag("")
                        } else {
                            ForEach(calendarManager.predefinedCalendars, id: \.calendarIdentifier) { calendar in
                                Text(calendar.title)
                                    .tag(calendar.calendarIdentifier)
                            }
                        }
                    }
                }
            }
            .headerProminence(.increased)
            
            Section("Sistema") {
                Button {
                    Task {
                        await invalidateCache()
                    }
                } label: {
                    HStack {
                        Text("Svuota Cache")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .disabled(isLoading)
            }
            
            Section("Info App") {
                HStack {
                    Text("Versione")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Esci")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Impostazioni")
        .inlineNavigationTitle()
        .alert("Cache", isPresented: $showingCacheAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cacheAlertMessage)
        }
        .alert("Conferma Logout", isPresented: $showingLogoutAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Vuoi davvero uscire dall'app?")
        }
        .onAppear {
            if calendarManager.isSyncEnabled {
                Task { let _ = await calendarManager.requestAccess() }
            }
        }
    }
    
    private func invalidateCache() async {
        isLoading = true
        do {
            try await APIClient.shared.invalidateCache()
            cacheAlertMessage = "La cache è stata svuotata con successo."
        } catch {
            cacheAlertMessage = "Errore durante lo svuotamento della cache: \(error.localizedDescription)"
        }
        isLoading = false
        showingCacheAlert = true
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
