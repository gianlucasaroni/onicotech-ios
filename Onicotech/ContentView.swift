import SwiftUI
internal import EventKit

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        if authManager.isAuthenticated {
            TabView {
                Tab("Home", systemImage: "house") {
                    NavigationStack {
                        DashboardView()
                    }
                }
                
                Tab("Appuntamenti", systemImage: "calendar") {
                    NavigationStack {
                        AppointmentListView()
                    }
                }
                
                Tab("Clienti", systemImage: "person.2") {
                    NavigationStack {
                        ClientListView()
                    }
                }
                
                Tab("Gestione", systemImage: "slider.horizontal.3") {
                    ManagementView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}

extension View {
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func phoneKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.phonePad)
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func emailKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
