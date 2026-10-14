import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var salonManager: SalonManager
    @State private var showingLogoutAlert = false
    
    var body: some View {
        Form {
            // MARK: - Profilo Utente
            if let user = authManager.user {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.accentColor, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 52, height: 52)
                            
                            Text(userInitials(user: user))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(user.firstName) \(user.lastName)")
                                .font(.headline)
                            
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text(user.isOwner ? "TITOLARE" : "COLLABORATRICE")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(user.isOwner ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                                    .foregroundStyle(user.isOwner ? Color.purple : Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - Canali & Prenotazioni
            Section("Canali e Clienti") {
                NavigationLink(destination: BookingSettingsView()) {
                    SettingsRow(
                        title: "Prenotazioni Online",
                        subtitle: "Link pubblico sede, slug e condivisione",
                        icon: "link.circle.fill",
                        iconColor: .purple
                    )
                }
            }
            
            // MARK: - Calendari & Sincronizzazione
            Section("Calendari e Sincronizzazione") {
                NavigationLink(destination: CalendarSyncSettingsView()) {
                    SettingsRow(
                        title: "Feed Calendario Esterno",
                        subtitle: "Apple Calendar, Google Calendar e iCal",
                        icon: "calendar.badge.clock",
                        iconColor: .blue
                    )
                }
                
                NavigationLink(destination: LocalCalendarSettingsView()) {
                    SettingsRow(
                        title: "Calendario Locale iOS",
                        subtitle: "Sincronizzazione EventKit su dispositivo",
                        icon: "iphone",
                        iconColor: .green
                    )
                }
            }
            
            // MARK: - Sistema
            Section("Applicazione") {
                NavigationLink(destination: SystemSettingsView()) {
                    SettingsRow(
                        title: "Sistema e Manutenzione",
                        subtitle: "Svuota cache, info server e versione",
                        icon: "gearshape.2.fill",
                        iconColor: .secondary
                    )
                }
            }
            
            // MARK: - Logout
            Section {
                Button(role: .destructive) {
                    showingLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Esci dall'Account", systemImage: "rectangle.portrait.and.arrow.right")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Impostazioni")
        .inlineNavigationTitle()
        .alert("Conferma Logout", isPresented: $showingLogoutAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Vuoi davvero uscire dall'app? Dovrai effettuare nuovamente l'accesso.")
        }
    }
    
    private func userInitials(user: User) -> String {
        let first = user.firstName.prefix(1).uppercased()
        let last = user.lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }
}

// MARK: - SettingsRow Component
private struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
