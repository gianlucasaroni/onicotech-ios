import SwiftUI
#if canImport(UIKit)
import UIKit

/// Haptic feedback styles matching Apple Human Interface Guidelines.
enum HapticType {
    case success
    case warning
    case error
    case selection
    case light
    case medium
    case heavy
}

enum Haptics {
    @MainActor
    static func play(_ type: HapticType) {
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}
#else
enum HapticType {
    case success, warning, error, selection, light, medium, heavy
}

enum Haptics {
    static func play(_ type: HapticType) {}
}
#endif
