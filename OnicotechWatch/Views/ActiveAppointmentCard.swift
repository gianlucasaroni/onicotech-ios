import SwiftUI

struct ActiveAppointmentCard: View {
    let appointment: WatchAppointment
    var onComplete: () -> Void
    var onOpenTimer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("IN CORSO")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                
                Spacer()
                
                Text(appointment.timeRangeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(appointment.clientName)
                .font(.headline)
                .fontWeight(.bold)
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
                        .font(.caption2)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
            
            HStack(spacing: 8) {
                Button(action: onComplete) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Fine")
                    }
                    .font(.caption.bold())
                }
                .tint(.green)
                
                Button(action: onOpenTimer) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text("Timer")
                    }
                    .font(.caption.bold())
                }
                .tint(.purple)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
