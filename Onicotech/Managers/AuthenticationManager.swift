import Foundation
internal import LocalAuthentication
import Security
import SwiftUI
import Combine

enum StorageKeys: Sendable {
    nonisolated static let authToken = "authToken"
    nonisolated static let refreshToken = "refreshToken"
    nonisolated static let biometricEmail = "biometricEmail"
    nonisolated static let biometricPassword = "biometricPassword"
    nonisolated static let isBiometricsEnabled = "isBiometricsEnabled"
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var hasBiometricsSaved = false
    @Published var biometricsType: LABiometryType = .none
    
    private var sessionExpiredObserver: Any?
    
    var hasBiometricHardware: Bool {
        biometricsType != .none
    }
    
    var canUseBiometrics: Bool {
        biometricsType != .none && hasBiometricsSaved
    }
    
    var biometricsName: String {
        switch biometricsType {
        case .faceID: return "FaceID"
        case .touchID: return "TouchID"
        case .opticID: return "OpticID"
        default: return "Biometria"
        }
    }
    
    var biometricsIconName: String {
        switch biometricsType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }
    
    init() {
        checkBiometrics()
        self.hasBiometricsSaved = KeychainHelper.shared.readString(key: StorageKeys.biometricEmail) != nil &&
                                  KeychainHelper.shared.readString(key: StorageKeys.biometricPassword) != nil
        
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
        
        // Save credentials in Keychain for biometric quick-login if supported
        if biometricsType != .none {
            KeychainHelper.shared.saveString(key: StorageKeys.biometricEmail, value: email)
            KeychainHelper.shared.saveString(key: StorageKeys.biometricPassword, value: password)
            UserDefaults.standard.set(true, forKey: StorageKeys.isBiometricsEnabled)
            self.hasBiometricsSaved = true
        }
        
        self.user = response.user
        self.isAuthenticated = true
    }
    
    func register(firstName: String, lastName: String, email: String, password: String) async throws {
        let response = try await APIClient.shared.register(firstName: firstName, lastName: lastName, email: email, password: password)
        saveTokens(accessToken: response.token, refreshToken: response.refreshToken)
        
        if biometricsType != .none {
            KeychainHelper.shared.saveString(key: StorageKeys.biometricEmail, value: email)
            KeychainHelper.shared.saveString(key: StorageKeys.biometricPassword, value: password)
            UserDefaults.standard.set(true, forKey: StorageKeys.isBiometricsEnabled)
            self.hasBiometricsSaved = true
        }
        
        self.user = response.user
        self.isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.authToken)
        UserDefaults.standard.removeObject(forKey: StorageKeys.refreshToken)
        self.isAuthenticated = false
        self.user = nil
    }
    
    func clearBiometrics() {
        KeychainHelper.shared.delete(key: StorageKeys.biometricEmail)
        KeychainHelper.shared.delete(key: StorageKeys.biometricPassword)
        UserDefaults.standard.removeObject(forKey: StorageKeys.isBiometricsEnabled)
        self.hasBiometricsSaved = false
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
        
        guard let email = KeychainHelper.shared.readString(key: StorageKeys.biometricEmail),
              let password = KeychainHelper.shared.readString(key: StorageKeys.biometricPassword) else {
            throw AuthError.noSavedCredentials
        }
        
        let reason = "Accedi al tuo account Onicotech con \(biometricsName)"
        
        let success: Bool
        do {
            success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel {
            throw AuthError.biometricsCancelled
        } catch {
            throw AuthError.biometricsFailed
        }
        
        guard success else {
            throw AuthError.biometricsFailed
        }
        
        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            saveTokens(accessToken: response.token, refreshToken: response.refreshToken)
            self.user = response.user
            self.isAuthenticated = true
        } catch {
            throw AuthError.credentialsInvalid
        }
    }
}

enum AuthError: LocalizedError {
    case biometricsNotAvailable
    case biometricsCancelled
    case biometricsFailed
    case noSavedCredentials
    case credentialsInvalid
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Autenticazione biometrica non disponibile su questo dispositivo."
        case .biometricsCancelled:
            return "Autenticazione annullata."
        case .biometricsFailed:
            return "Riconoscimento biometrico non riuscito."
        case .noSavedCredentials:
            return "Nessuna credenziale salvata per l'accesso rapido. Effettua l'accesso con email e password."
        case .credentialsInvalid:
            return "Credenziali salvate non più valide. Inserisci nuovamente email e password."
        }
    }
}
