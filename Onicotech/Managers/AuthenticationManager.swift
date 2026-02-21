import Foundation
internal import LocalAuthentication
import Security
import SwiftUI
import Combine

enum StorageKeys {
    static let authToken = "authToken"
    static let refreshToken = "refreshToken"
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isBiometricsEnabled = false
    @Published var biometricsType: LABiometryType = .none
    
    private var sessionExpiredObserver: Any?
    
    init() {
        checkBiometrics()
        
        // Listen for session expiry from APIClient
        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let authManager = self else { return }
            Task { @MainActor in
                authManager.logout()
            }
        }
        
        if let _ = UserDefaults.standard.string(forKey: StorageKeys.authToken) {
            self.isAuthenticated = true
            
            Task {
                do {
                    let user = try await APIClient.shared.getProfile()
                    self.user = user
                } catch {
                    print("Sessione scaduta o non valida: \(error)")
                    self.logout()
                }
            }
        }
    }
    
    deinit {
        if let observer = sessionExpiredObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(email: email, password: password)
        saveTokens(accessToken: response.token, refreshToken: response.refreshToken)
        self.user = response.user
        self.isAuthenticated = true
    }
    
    func register(firstName: String, lastName: String, email: String, password: String) async throws {
        let response = try await APIClient.shared.register(firstName: firstName, lastName: lastName, email: email, password: password)
        saveTokens(accessToken: response.token, refreshToken: response.refreshToken)
        self.user = response.user
        self.isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.authToken)
        UserDefaults.standard.removeObject(forKey: StorageKeys.refreshToken)
        self.isAuthenticated = false
        self.user = nil
    }
    
    private func saveTokens(accessToken: String, refreshToken: String) {
        UserDefaults.standard.set(accessToken, forKey: StorageKeys.authToken)
        UserDefaults.standard.set(refreshToken, forKey: StorageKeys.refreshToken)
    }
    
    // MARK: - Biometrics
    func checkBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricsType = context.biometryType
        } else {
            biometricsType = .none
        }
    }
    
    func loginWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometricsNotAvailable
        }
        
        let reason = "Accedi con FaceID"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            
            if success {
                 self.isAuthenticated = true
            }
        } catch {
            throw AuthError.biometricsFailed
        }
    }
}

enum AuthError: Error {
    case biometricsNotAvailable
    case biometricsFailed
}
