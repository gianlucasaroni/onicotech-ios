import SwiftUI

struct SalonBadge: View {
    let name: String
    var isDefault: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.2.fill")
                .font(.caption2.weight(.bold))
            Text(name)
                .font(.caption2.weight(.medium))
            if isDefault {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.12))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }
}
