import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Manages synchronization between the iOS App and Apple Watch companion app via WatchConnectivity.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false
    
    #if canImport(WatchConnectivity)
    private var session: WCSession?
    #endif
    private var currentToken: String?
    private var currentSalon: Salon?
    
    override init() {
        super.init()
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            self.session = session
            session.delegate = self
            session.activate()
        }
        #endif
    }
    
    /// Synchronizes authentication token, active salon and backend server URL with the Apple Watch.
    func syncState(token: String? = nil, salon: Salon? = nil) {
        if let token { self.currentToken = token }
        if let salon { self.currentSalon = salon }
        
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported(), let session, session.activationState == .activated else {
            return
        }
        
        let tokenToSync = currentToken ?? UserDefaults.standard.string(forKey: StorageKeys.authToken) ?? ""
        var payload: [String: Any] = [
            "authToken": tokenToSync,
            "serverUrl": APIClient.baseServerURL
        ]
        
        if let salon = currentSalon {
            payload["salonId"] = salon.id.uuidString
            payload["salonName"] = salon.name
        } else if let savedSalonId = UserDefaults.standard.string(forKey: "selectedSalonId") {
            payload["salonId"] = savedSalonId
            payload["salonName"] = "Tutte le Sedi"
        }
        
        do {
            try session.updateApplicationContext(payload)
        } catch {
            print("[WatchConnectivity] updateApplicationContext error: \(error.localizedDescription)")
        }
        
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { err in
                print("[WatchConnectivity] sendMessage error: \(err.localizedDescription)")
            }
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            if activationState == .activated {
                self.syncState()
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Required for iOS
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for multi-watch support
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            if message["request"] as? String == "syncState" {
                let token = UserDefaults.standard.string(forKey: StorageKeys.authToken) ?? ""
                var reply: [String: Any] = [
                    "authToken": token,
                    "serverUrl": APIClient.baseServerURL
                ]
                if let savedSalonId = UserDefaults.standard.string(forKey: "selectedSalonId") {
                    reply["salonId"] = savedSalonId
                }
                replyHandler(reply)
            } else {
                replyHandler(["status": "ok"])
            }
        }
    }
}
#endif
