import SwiftUI
internal import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Logo or Title
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(.pink)
                    Text("Onicotech")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 32)
                
                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                // Login Button
                Button {
                    Task {
                        await login()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Accedi")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                // Biometrics
                if authManager.biometricsType != .none {
                    Button {
                        Task {
                            try? await authManager.loginWithBiometrics()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "faceid")
                            Text("Accedi con FaceID")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                // Register Link
                NavigationLink(destination: RegisterView()) {
                    Text("Non hai un account? Registrati")
                        .foregroundStyle(.pink)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.login(email: email, password: password)
        } catch {
            errorMessage = "Credenziali non valide o errore di connessione."
        }
        isLoading = false
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
