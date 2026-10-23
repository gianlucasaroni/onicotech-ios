import SwiftUI

struct NextAppointmentCard: View {
    let appointment: WatchAppointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PROSSIMO")
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Text(appointment.startTime)
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }
            
            Text(appointment.clientName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(appointment.serviceName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            if appointment.hasAllergies, let allergies = appointment.allergies {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(allergies)
                        .font(.caption2.bold())
                        .lineLimit(2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.2))
                .foregroundStyle(.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
