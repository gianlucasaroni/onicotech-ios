import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Crea Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Inizia a gestire il tuo salone")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 32)
                
                // Form
                VStack(spacing: 16) {
                    TextField("Nome", text: $firstName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.givenName)
                    
                    TextField("Cognome", text: $lastName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.familyName)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                        .textContentType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                    
                    SecureField("Conferma Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                }
                .padding(.horizontal)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    Task {
                        await register()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Registrati")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.pink : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(!isValid || isLoading)
                
                Button("Hai già un account? Accedi") {
                    dismiss()
                }
                .foregroundStyle(.pink)
            }
            .padding()
        }
    }
    
    private var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty && password.count >= 6 && password == confirmPassword
    }
    
    private func register() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.register(
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password
            )
            // Auth check in ContentView will auto-dismiss login flow
        } catch {
            errorMessage = "Errore durante la registrazione. Riprova."
        }
        isLoading = false
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthenticationManager())
}
