import SwiftUI
internal import EventKit

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var salonManager: SalonManager
    @ObservedObject var calendarManager = CalendarManager.shared
    @State private var showingCacheAlert = false
    @State private var cacheAlertMessage = ""
    @State private var isLoading = false
    @State private var showingLogoutAlert = false
    
    // External iCal Feed (P6 / Fase 13)
    @State private var staffMembers: [SalonMember] = []
    @State private var selectedStaffId: UUID? = nil
    @State private var loadingStaff = false
    @State private var showingCopiedAlert = false
    @State private var resettingCalendarToken = false
    
    var body: some View {
        Form {
            Section("Feed Calendario Esterno (Apple / Google)") {
                if loadingStaff {
                    HStack {
                        ProgressView()
                        Text("Caricamento collaboratrici...")
                            .foregroundStyle(.secondary)
                    }
                } else if staffMembers.isEmpty {
                    Text("Nessuna collaboratrice configurata per questa sede.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    if staffMembers.count > 1 {
                        Picker("Collaboratrice", selection: $selectedStaffId) {
                            ForEach(staffMembers) { member in
                                Text(member.displayName).tag(Optional(member.id))
                            }
                        }
                    }
                    
                    if let member = currentSelectedMember {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sincronizzazione Automatica")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Gli appuntamenti si aggiornano da soli su Apple Calendar o Google Calendar tramite feed RFC 5545.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        
                        Button {
                            subscribeAppleCalendar(member: member)
                        } label: {
                            Label("Sottoscrivi su Apple Calendar", systemImage: "calendar.badge.plus")
                                .fontWeight(.medium)
                        }
                        
                        Button {
                            openGoogleCalendar(member: member)
                        } label: {
                            Label("Aggiungi a Google Calendar", systemImage: "arrow.up.right.square")
                        }
                        
                        Button {
                            copyFeedLink(member: member)
                        } label: {
                            Label("Copia Link Feed Privato", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive) {
                            Task {
                                await resetToken(member: member)
                            }
                        } label: {
                            if resettingCalendarToken {
                                ProgressView()
                            } else {
                                Label("Rigenera Link Privato", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(resettingCalendarToken)
                    }
                }
            }
            .headerProminence(.increased)
            
            Section("Sincronizzazione Locale (EventKit)") {
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
        .alert("Link Copiato!", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Il link del feed iCalendar (.ics) è stato copiato negli appunti. Puoi incollarlo in Outlook o in qualsiasi altra applicazione di calendario.")
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
        .task {
            await loadStaff()
        }
    }
    
    private var currentSelectedMember: SalonMember? {
        if let id = selectedStaffId {
            return staffMembers.first(where: { $0.id == id })
        }
        return staffMembers.first
    }
    
    private func subscribeAppleCalendar(member: SalonMember) {
        if let url = member.calendarWebcalURL(baseURL: APIClient.baseServerURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openGoogleCalendar(member: SalonMember) {
        if let url = member.googleCalendarSubscribeURL(baseURL: APIClient.baseServerURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyFeedLink(member: SalonMember) {
        if let url = member.calendarFeedURL(baseURL: APIClient.baseServerURL)?.absoluteString {
            UIPasteboard.general.string = url
            showingCopiedAlert = true
        }
    }

    private func resetToken(member: SalonMember) async {
        guard let salonId = salonManager.selectedSalonId ?? staffMembers.first?.salonId else { return }
        resettingCalendarToken = true
        do {
            let updated = try await APIClient.shared.resetCalendarToken(salonId: salonId, memberId: member.id)
            if let idx = staffMembers.firstIndex(where: { $0.id == updated.id }) {
                staffMembers[idx] = updated
            }
        } catch {
            print("Failed to reset token: \(error)")
        }
        resettingCalendarToken = false
    }

    private func loadStaff() async {
        guard let salonId = salonManager.selectedSalonId ?? salonManager.defaultSalon?.id else { return }
        loadingStaff = true
        do {
            staffMembers = try await APIClient.shared.getSalonStaff(salonId: salonId)
            if selectedStaffId == nil {
                selectedStaffId = staffMembers.first?.id
            }
        } catch {
            print("Failed to load staff: \(error)")
        }
        loadingStaff = false
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
