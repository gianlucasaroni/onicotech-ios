import SwiftUI

struct SalonPickerMenu: View {
    @EnvironmentObject var salonManager: SalonManager
    var showAllOption: Bool = true
    var onSelectionChanged: (() -> Void)? = nil
    
    var body: some View {
        Menu {
            if showAllOption && salonManager.hasMultipleSalons {
                Button {
                    salonManager.selectSalon(nil)
                    onSelectionChanged?()
                } label: {
                    HStack {
                        Text("Tutte le Sedi")
                        if salonManager.selectedSalon == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Divider()
            }
            
            ForEach(salonManager.salons) { salon in
                Button {
                    salonManager.selectSalon(salon)
                    onSelectionChanged?()
                } label: {
                    HStack {
                        Text(salon.name)
                        if salon.isDefault {
                            Text(" (Predefinita)")
                        }
                        if salonManager.selectedSalon?.id == salon.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                
                Text(salonManager.selectedSalon?.name ?? "Tutte le Sedi")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if salonManager.activeRole == "staff" {
                    Text("Staff")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                if salonManager.hasMultipleSalons {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
