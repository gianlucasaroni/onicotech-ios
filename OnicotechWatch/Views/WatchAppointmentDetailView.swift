import SwiftUI

struct WatchAppointmentDetailView: View {
    let appointment: WatchAppointment
    var onComplete: () -> Void
    var onOpenTimer: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text(appointment.clientName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(appointment.serviceName)
                        .font(.caption)
                        .foregroundStyle(.pink)
                }
                
                Divider()
                
                // Time & Status
                HStack {
                    Label(appointment.timeRangeFormatted, systemImage: "clock")
                        .font(.caption2)
                    
                    Spacer()
                    
                    Text(appointment.isCompleted ? "Completato" : (appointment.isPending ? "In Attesa" : "Confermato"))
                        .font(.caption2.bold())
                        .foregroundStyle(appointment.isCompleted ? .green : .blue)
                }
                
                // Allergies Alert
                if appointment.hasAllergies, let allergies = appointment.allergies {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("ATTENZIONE ALLERGIE")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                        
                        Text(allergies)
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Notes
                if let notes = appointment.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOTE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Actions
                if !appointment.isCompleted {
                    VStack(spacing: 6) {
                        Button(action: onComplete) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Segna Completato")
                            }
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                        }
                        .tint(.green)
                        
                        Button(action: onOpenTimer) {
                            HStack {
                                Image(systemName: "timer")
                                Text("Avvia Timer Lampada")
                            }
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                        }
                        .tint(.purple)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Dettaglio")
    }
}
