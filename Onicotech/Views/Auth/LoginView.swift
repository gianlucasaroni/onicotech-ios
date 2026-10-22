import SwiftUI
internal import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPasswordAlert = false
    @State private var forgotPasswordEmail = ""
    @State private var forgotPasswordNotice: String? = nil
    @State private var showNoticeAlert = false
    
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
                    
                    HStack {
                        Spacer()
                        Button("Password dimenticata?") {
                            forgotPasswordEmail = email
                            showForgotPasswordAlert = true
                        }
                        .font(.footnote)
                        .foregroundStyle(.pink)
                    }
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
                if authManager.canUseBiometrics {
                    Button {
                        Task {
                            await loginWithBiometrics()
                        }
                    } label: {
                        HStack {
                            Image(systemName: authManager.biometricsIconName)
                            Text("Accedi con \(authManager.biometricsName)")
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.pink)
                    }
                    .disabled(isLoading)
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
            .scrollDismissesKeyboard(.interactively)
            .alert("Recupero Password", isPresented: $showForgotPasswordAlert) {
                TextField("Email del tuo account", text: $forgotPasswordEmail)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                Button("Invia Link") {
                    Task {
                        await sendForgotPassword()
                    }
                }
                Button("Annulla", role: .cancel) { }
            } message: {
                Text("Inserisci la tua email. Ti invieremo un link per reimpostare la tua password.")
            }
            .alert("Recupero Password", isPresented: $showNoticeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(forgotPasswordNotice ?? "")
            }
        }
    }
    
    private func sendForgotPassword() async {
        let cleanEmail = forgotPasswordEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else { return }
        do {
            let msg = try await APIClient.shared.forgotPassword(email: cleanEmail)
            await MainActor.run {
                forgotPasswordNotice = msg
                showNoticeAlert = true
                Haptics.play(.success)
            }
        } catch {
            await MainActor.run {
                forgotPasswordNotice = "Se l'indirizzo email inserito è registrato, riceverai a breve un link per reimpostare la tua password."
                showNoticeAlert = true
                Haptics.play(.light)
            }
        }
    }
    
    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.login(email: email, password: password)
            Haptics.play(.success)
        } catch {
            errorMessage = "Credenziali non valide o errore di connessione."
            Haptics.play(.error)
        }
        isLoading = false
    }
    
    private func loginWithBiometrics() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.loginWithBiometrics()
            Haptics.play(.success)
        } catch AuthError.biometricsCancelled {
            // User cancelled FaceID, do not show error
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
            Haptics.play(.error)
        } catch {
            errorMessage = "Autenticazione con \(authManager.biometricsName) non riuscita."
            Haptics.play(.error)
        }
        isLoading = false
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
