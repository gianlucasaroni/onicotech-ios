import SwiftUI

struct SalonBadge: View {
    let name: String
    var isDefault: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 9, weight: .bold))
            Text(name)
                .font(.system(size: 11, weight: .medium))
            if isDefault {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
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
