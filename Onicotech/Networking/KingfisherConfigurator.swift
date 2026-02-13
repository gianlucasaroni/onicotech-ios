import Foundation
import Kingfisher

struct KingfisherConfigurator {
    static func configure() {
        let modifier = AnyModifier { request in
            var r = request
            // Retrieve token from UserDefaults (or Keychain)
            if let token = UserDefaults.standard.string(forKey: "authToken") {
                r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return r
        }
        
        KingfisherManager.shared.defaultOptions = [
            .requestModifier(modifier),
            .cacheOriginalImage
        ]
    }
}
