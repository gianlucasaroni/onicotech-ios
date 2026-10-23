import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @EnvironmentObject var appointmentsVM: WatchAppointmentsViewModel
    @State private var selectedTab: Int = 0
    
    var body: some View {
        if !sessionManager.isAuthenticated {
            UnauthenticatedWatchView()
        } else {
            TabView(selection: $selectedTab) {
                // Tab 1: Today's Appointments & Active Treatment
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 10) {
                            // Salon & Progress Header
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.pink)
                                
                                Text(sessionManager.salonName ?? "Salone")
                                    .font(.caption2.bold())
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if appointmentsVM.totalCount > 0 {
                                    Text("\(appointmentsVM.completedCount)/\(appointmentsVM.totalCount)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            // Active Treatment Card (if ongoing)
                            if let active = appointmentsVM.activeAppointment {
                                ActiveAppointmentCard(
                                    appointment: active,
                                    onComplete: {
                                        appointmentsVM.markCompleted(id: active.id)
                                    },
                                    onOpenTimer: {
                                        selectedTab = 1
                                    }
                                )
                            }
                            
                            // Next Client Card (if exists)
                            if let next = appointmentsVM.nextAppointment {
                                NextAppointmentCard(appointment: next)
                            }
                            
                            // Full Agenda List
                            if appointmentsVM.appointments.isEmpty && !appointmentsVM.isLoading {
                                VStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                    Text("Nessun appuntamento oggi")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 16)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("AGENDA OGGI")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    
                                    ForEach(appointmentsVM.appointments) { apt in
                                        NavigationLink(destination: WatchAppointmentDetailView(
                                            appointment: apt,
                                            onComplete: {
                                                appointmentsVM.markCompleted(id: apt.id)
                                            },
                                            onOpenTimer: {
                                                selectedTab = 1
                                            }
                                        )) {
                                            AppointmentRow(appointment: apt)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .navigationTitle("Onicotech")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                Task {
                                    await appointmentsVM.loadAppointments()
                                }
                            }) {
                                if appointmentsVM.isLoading {
                                    ProgressView()
                                        .tint(.pink)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                .tag(0)
                
                // Tab 2: Dedicated Nail Curing Timer
                NavigationStack {
                    CuringTimerView()
                }
                .tag(1)
            }
            .task {
                await appointmentsVM.loadAppointments()
            }
        }
    }
}

// MARK: - Appointment Row Subview
private struct AppointmentRow: View {
    let appointment: WatchAppointment
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appointment.isCompleted ? Color.green : (appointment.isPending ? Color.orange : Color.blue))
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(appointment.clientName)
                    .font(.caption2.bold())
                    .lineLimit(1)
                
                Text(appointment.serviceName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if appointment.hasAllergies {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
            }
            
            Text(appointment.startTime)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Unauthenticated Watch View
private struct UnauthenticatedWatchView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "applewatch.and.arrow.forward")
                .font(.title2)
                .foregroundStyle(.pink)
            
            Text("Onicotech")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Apri l'app su iPhone per sincronizzare il tuo salone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Sincronizza") {
                sessionManager.requestPhoneSync()
            }
            .font(.caption.bold())
            .tint(.pink)
        }
        .padding()
    }
}
