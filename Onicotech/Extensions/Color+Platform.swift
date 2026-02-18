import SwiftUI

extension Color {
    /// Cross-platform background color (equivalent to iOS systemBackground)
    static var systemBackgroundCompat: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    /// Cross-platform grouped background color (equivalent to iOS systemGroupedBackground)
    static var groupedBackgroundCompat: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    /// Cross-platform secondary grouped background color
    static var secondaryGroupedBackgroundCompat: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
