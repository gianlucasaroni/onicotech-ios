import Foundation
import WatchConnectivity
import Combine

/// Manages WCSession on the Apple Watch to receive authentication credentials and active salon from the iPhone.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()
    
    @Published var authToken: String?
    @Published var salonId: String?
    @Published var salonName: String?
    @Published var serverUrl: String = "http://192.168.1.14:8282/api/v1"
    @Published var isReachable: Bool = false
    
    private let userDefaultsTokenKey = "watchAuthToken"
    private let userDefaultsSalonIdKey = "watchSalonId"
    private let userDefaultsSalonNameKey = "watchSalonName"
    private let userDefaultsServerUrlKey = "watchServerUrl"
    
    var isAuthenticated: Bool {
        guard let token = authToken, !token.isEmpty else { return false }
        return true
    }
    
    override init() {
        super.init()
        // Restore locally cached state
        self.authToken = UserDefaults.standard.string(forKey: userDefaultsTokenKey)
        self.salonId = UserDefaults.standard.string(forKey: userDefaultsSalonIdKey)
        self.salonName = UserDefaults.standard.string(forKey: userDefaultsSalonNameKey) ?? "Salone"
        if let savedServer = UserDefaults.standard.string(forKey: userDefaultsServerUrlKey) {
            self.serverUrl = savedServer
        }
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    /// Requests the iPhone to immediately send back the active authentication credentials.
    func requestPhoneSync() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        
        session.sendMessage(["request": "syncState"]) { [weak self] reply in
            Task { @MainActor in
                self?.handlePayload(reply)
            }
        } errorHandler: { error in
            print("[WatchSession] requestPhoneSync error: \(error.localizedDescription)")
        }
    }
    
    private func handlePayload(_ payload: [String: Any]) {
        if let token = payload["authToken"] as? String {
            self.authToken = token
            UserDefaults.standard.set(token, forKey: userDefaultsTokenKey)
        }
        if let salonId = payload["salonId"] as? String {
            self.salonId = salonId
            UserDefaults.standard.set(salonId, forKey: userDefaultsSalonIdKey)
        }
        if let salonName = payload["salonName"] as? String {
            self.salonName = salonName
            UserDefaults.standard.set(salonName, forKey: userDefaultsSalonNameKey)
        }
        if let serverUrl = payload["serverUrl"] as? String {
            self.serverUrl = serverUrl
            UserDefaults.standard.set(serverUrl, forKey: userDefaultsServerUrlKey)
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if activationState == .activated {
                self.requestPhoneSync()
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.handlePayload(applicationContext)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.handlePayload(message)
        }
    }
}
