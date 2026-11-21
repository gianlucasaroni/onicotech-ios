import SwiftUI
internal import EventKit

enum AppTab: Hashable {
    case home
    case appointments
    case clients
    case management
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var salonManager: SalonManager
    @State private var selectedTab: AppTab = .home
    @State private var commandPaletteState = CommandPaletteState()
    
    var body: some View {
        if authManager.isAuthenticated {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house", value: AppTab.home) {
                    NavigationStack {
                        DashboardView()
                    }
                }
                
                Tab("Appuntamenti", systemImage: "calendar", value: AppTab.appointments) {
                    NavigationStack {
                        AppointmentListView()
                    }
                }
                
                Tab("Clienti", systemImage: "person.2", value: AppTab.clients) {
                    NavigationStack {
                        ClientListView()
                    }
                }
                
                Tab("Gestione", systemImage: "square.grid.2x2", value: AppTab.management) {
                    ManagementView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .task {
                await salonManager.loadSalons()
                configureGlobalCommandPalette()
            }
            .background {
                Button("") {
                    commandPaletteState.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
            }
            .environment(\.commandPaletteState, commandPaletteState)
            .overlay(alignment: .center) {
                CommandPaletteView(state: commandPaletteState)
            }
        } else {
            LoginView()
        }
    }
    
    private func configureGlobalCommandPalette() {
        commandPaletteState.setSalonManager(salonManager)
        commandPaletteState.onNavigateAppointments = { _, _ in
            selectedTab = .appointments
        }
        commandPaletteState.onNavigateClients = { _, _ in
            selectedTab = .clients
        }
        commandPaletteState.onNavigateServices = {
            selectedTab = .management
        }
        commandPaletteState.onNavigateProducts = { _, _, _ in
            selectedTab = .management
        }
        commandPaletteState.onNavigateExpenses = { _, _ in
            selectedTab = .management
        }
        commandPaletteState.onNavigateStatistics = {
            selectedTab = .management
        }
        commandPaletteState.onNavigateTaxes = {
            selectedTab = .management
        }
        commandPaletteState.onNavigatePromotions = { _ in
            selectedTab = .management
        }
        commandPaletteState.onNavigateSettings = { _ in
            selectedTab = .management
        }
    }
}

// Environment key for command palette
struct CommandPaletteStateKey: EnvironmentKey {
    static let defaultValue: CommandPaletteState? = nil
}

extension EnvironmentValues {
    var commandPaletteState: CommandPaletteState? {
        get { self[CommandPaletteStateKey.self] }
        set { self[CommandPaletteStateKey.self] = newValue }
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
