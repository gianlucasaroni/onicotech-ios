import SwiftUI
internal import EventKit

struct ContentView: View {
    var body: some View {
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
            
            Tab("Servizi", systemImage: "sparkles") {
                NavigationStack {
                    ServiceListView()
                }
            }
            
            Tab("Impostazioni", systemImage: "gear") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
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
