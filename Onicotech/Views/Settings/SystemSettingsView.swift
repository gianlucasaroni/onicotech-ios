import SwiftUI

struct SystemSettingsView: View {
    @State private var isLoading = false
    @State private var showingCacheAlert = false
    @State private var cacheAlertMessage = ""
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        Form {
            Section {
                Button {
                    Task { await invalidateCache() }
                } label: {
                    HStack {
                        Label("Svuota Cache Locale", systemImage: "trash")
                            .foregroundStyle(.red)
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoading)
            } header: {
                Text("Memoria e Dati")
            } footer: {
                Text("Rimuove i dati temporanei scaricati dall'applicazione per forzare un ricaricamento completo dal server.")
                    .font(.caption2)
            }
            
            Section("Connessione Server") {
                HStack {
                    Text("API Server")
                    Spacer()
                    Text(APIClient.baseServerURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("Portale Web")
                    Spacer()
                    Text(APIClient.baseWebURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Section("Informazioni Applicazione") {
                HStack {
                    Text("Nome App")
                    Spacer()
                    Text("Onicotech")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Versione")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(appBuild)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Sistema")
        .inlineNavigationTitle()
        .alert("Cache", isPresented: $showingCacheAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cacheAlertMessage)
        }
    }
    
    private func invalidateCache() async {
        isLoading = true
        do {
            try await APIClient.shared.invalidateCache()
            cacheAlertMessage = "La cache locale è stata svuotata con successo."
        } catch {
            cacheAlertMessage = "Errore durante lo svuotamento della cache: \(error.localizedDescription)"
        }
        isLoading = false
        showingCacheAlert = true
    }
}
