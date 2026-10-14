import SwiftUI

struct CalendarSyncSettingsView: View {
    @EnvironmentObject var salonManager: SalonManager
    @State private var staffMembers: [SalonMember] = []
    @State private var selectedStaffId: UUID? = nil
    @State private var loadingStaff = false
    @State private var showingCopiedAlert = false
    @State private var resettingCalendarToken = false
    @State private var showingResetConfirmation = false
    
    private var currentSelectedMember: SalonMember? {
        if let id = selectedStaffId {
            return staffMembers.first(where: { $0.id == id })
        }
        return staffMembers.first
    }
    
    var body: some View {
        Form {
            if loadingStaff {
                Section {
                    HStack {
                        ProgressView()
                        Text("Caricamento collaboratrici...")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if staffMembers.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nessuna collaboratrice",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Nessuna collaboratrice configurata per la sede selezionata.")
                    )
                }
            } else {
                if staffMembers.count > 1 {
                    Section("Collaboratrice") {
                        Picker("Seleziona Collaboratrice", selection: $selectedStaffId) {
                            ForEach(staffMembers) { member in
                                Text(member.displayName).tag(Optional(member.id))
                            }
                        }
                    }
                }
                
                if let member = currentSelectedMember {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sincronizzazione Automatica")
                                .font(.headline)
                            Text("Gli appuntamenti della collaboratrice si sincronizzano automaticamente con le applicazioni di calendario esterne tramite feed RFC 5545.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Button {
                            subscribeAppleCalendar(member: member)
                        } label: {
                            HStack {
                                Label("Sottoscrivi su Apple Calendar", systemImage: "calendar.badge.plus")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button {
                            openGoogleCalendar(member: member)
                        } label: {
                            HStack {
                                Label("Aggiungi a Google Calendar", systemImage: "arrow.up.right.square")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button {
                            copyFeedLink(member: member)
                        } label: {
                            Label("Copia Link Feed Privato (.ics)", systemImage: "doc.on.doc")
                        }
                    } header: {
                        Text("Collega Calendario (\(member.displayName))")
                    } footer: {
                        Text("Il link del feed è personale e sicuro. Non condividerlo con persone non autorizzate.")
                            .font(.caption2)
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            if resettingCalendarToken {
                                HStack {
                                    ProgressView()
                                    Text("Rigenerazione in corso...")
                                }
                            } else {
                                Label("Rigenera Token Privato", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(resettingCalendarToken)
                    } header: {
                        Text("Sicurezza Feed")
                    } footer: {
                        Text("Se sospetti che il link sia stato compromesso, rigeneralo: i calendari già collegati dovranno essere aggiornati col nuovo link.")
                            .font(.caption2)
                    }
                }
            }
        }
        .navigationTitle("Feed Calendari Esterni")
        .inlineNavigationTitle()
        .alert("Link Copiato!", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Il link del feed iCalendar (.ics) è stato copiato negli appunti. Puoi incollarlo in Outlook o in qualsiasi altra applicazione.")
        }
        .alert("Rigenerare il Link Privato?", isPresented: $showingResetConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Rigenera", role: .destructive) {
                if let member = currentSelectedMember {
                    Task { await resetToken(member: member) }
                }
            }
        } message: {
            Text("Il vecchio link del feed smetterà immediatamente di funzionare. Dovrai collegare nuovamente Apple Calendar o Google Calendar.")
        }
        .task {
            await loadStaff()
        }
    }
    
    private func subscribeAppleCalendar(member: SalonMember) {
        if let url = member.calendarWebcalURL(baseURL: APIClient.baseServerURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    private func openGoogleCalendar(member: SalonMember) {
        if let url = member.googleCalendarSubscribeURL(baseURL: APIClient.baseServerURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    private func copyFeedLink(member: SalonMember) {
        if let url = member.calendarFeedURL(baseURL: APIClient.baseServerURL)?.absoluteString {
            #if os(iOS)
            UIPasteboard.general.string = url
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url, forType: .string)
            #endif
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
}
