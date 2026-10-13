import SwiftUI
import Kingfisher
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AppointmentDetailView: View {
    let appointmentId: UUID
    let initialAppointment: Appointment
    var viewModel: AppointmentViewModel
    
    @EnvironmentObject var salonManager: SalonManager
    @Environment(\.dismiss) private var dismiss
    
    private var appointment: Appointment {
        if let live = viewModel.appointments.first(where: { $0.id == appointmentId }) {
            return live
        }
        return initialAppointment
    }
    
    var statusColor: Color {
        switch appointment.status {
        case .scheduled: return .blue
        case .pending: return .orange
        case .completed: return .green
        case .rescheduled: return .purple
        case .cancelled: return .red
        case .none: return .gray
        }
    }
    
    @State private var showEditSheet = false
    @State private var photos: [Photo] = []
    @State private var selectedPhoto: Photo?
    @State private var showSourcePicker = false
    @State private var showGallery = false
    @State private var showCamera = false
    #if os(iOS)
    @State private var inputImage: UIImage?
    #else
    @State private var inputImageData: Data?
    #endif
    @State private var isUploading = false

    var body: some View {
        List {
            // Status & Time
            Section {
                if let salon = appointment.salon {
                    HStack {
                        Label("Sede", systemImage: "building.2")
                        Spacer()
                        Text(salon.name)
                            .fontWeight(.medium)
                        if let city = salon.city, !city.isEmpty {
                            Text("(\(city))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let staff = appointment.staffMember {
                    HStack {
                        Label("Operatrice", systemImage: "person.badge.shield.checkmark")
                        Spacer()
                        Text(staff.displayName)
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Label("Data", systemImage: "calendar")
                    Spacer()
                    Text(formattedDate)
                }
                
                HStack {
                    Label("Orario", systemImage: "clock")
                    Spacer()
                    Text(appointment.timeRange)
                        .monospacedDigit()
                }
                
                if let status = appointment.status {
                    HStack {
                        Label("Stato", systemImage: status.iconName)
                        Spacer()
                        Text(status.displayName)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.12))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Quick Status Actions
            if appointment.status == .pending {
                Section("Gestione Richiesta Online") {
                    Button {
                        Task {
                            _ = await viewModel.confirmAppointment(id: appointmentId)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Approva Prenotazione Online", systemImage: "checkmark.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .tint(.green)
                    
                    Button(role: .destructive) {
                        Task {
                            _ = await viewModel.cancelAppointment(id: appointmentId)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Rifiuta Prenotazione", systemImage: "xmark.circle")
                            Spacer()
                        }
                    }
                }
            } else if appointment.status == .scheduled {
                Section {
                    Button {
                        Task {
                            _ = await viewModel.completeAppointment(id: appointmentId)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Segna come Completato", systemImage: "checkmark.seal.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .tint(.blue)
                    
                    Button {
                        Task {
                            _ = await viewModel.cancelAppointment(id: appointmentId)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Annulla Appuntamento", systemImage: "xmark.circle")
                            Spacer()
                        }
                    }
                    .tint(.orange)
                }
            }
            
            // Client
            if let client = appointment.client {
                Section("Cliente") {
                    HStack {
                        Label(client.fullName, systemImage: "person")
                        Spacer()
                        if let tag = client.customerTag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let allergies = client.allergies, !allergies.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ATTENZIONE ALLERGIE / SICUREZZA")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                                Text(allergies)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color.red.opacity(0.08))
                    }
                    
                    if let nailType = client.nailType, !nailType.isEmpty {
                        HStack {
                            Label("Tipologia Unghie", systemImage: "sparkles")
                            Spacer()
                            Text(nailType + (client.preferredShape.map { " • \($0)" } ?? ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let techNotes = client.technicalNotes, !techNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Note Tecniche & Basi", systemImage: "paintpalette")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(techNotes)
                                .font(.subheadline)
                        }
                    }
                    
                    if let phone = client.phone, !phone.isEmpty {
                        HStack(spacing: 12) {
                            Link(destination: URL(string: "tel:\(cleanPhoneNumber(phone))")!) {
                                Label("Chiama", systemImage: "phone.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            Link(destination: whatsappURL(phone: phone)) {
                                Label("WhatsApp", systemImage: "message.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        
                        if let staff = appointment.staffMember {
                            Link(destination: staffWhatsappURL(staff: staff)) {
                                Label("Invia Scheda ad Operatrice (\(staff.displayName))", systemImage: "arrowshape.turn.up.right.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }
            }
            
            // Services
            if let services = appointment.services, !services.isEmpty {
                Section("Servizi") {
                    ForEach(services) { service in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                    .font(.body)
                                Text(service.formattedDuration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(service.formattedPrice)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Totale Trattamenti")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(appointment.formattedTotalPrice)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Reserved Products
            if let products = appointment.products, !products.isEmpty {
                Section("Prodotti Riservati (Ritiro in Salone)") {
                    ForEach(products) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.quantity)x \(item.product?.name ?? "Prodotto")")
                                    .font(.body)
                                if let cat = item.product?.category {
                                    Text(cat)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.formattedSubtotal)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Photos
            Section("Galleria") {
                PhotoHorizontalList(
                    photos: photos,
                    isUploading: isUploading,
                    size: 100,
                    onPhotoSelected: { photo in
                        selectedPhoto = photo
                    }
                )
                
                Button {
                    showSourcePicker = true
                } label: {
                    Label("Aggiungi Foto", systemImage: "camera")
                }
            }
            
            // Notes
            if let notes = appointment.notes, !notes.isEmpty {
                Section("Note") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("Dettaglio Appuntamento")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifica") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AppointmentFormView(viewModel: viewModel, appointment: appointment)
        }
        #if os(iOS)
        .photoSourcePicker(
            showSourcePicker: $showSourcePicker,
            showGallery: $showGallery,
            showCamera: $showCamera,
            selectedImage: $inputImage
        )
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullscreenPhotoViewer(photos: photos, initialPhoto: photo, title: "Galleria")
        }
        .onChange(of: inputImage) {
            uploadSelectedImage()
        }
        #else
        .photoSourcePicker(
            showSourcePicker: $showSourcePicker,
            showGallery: $showGallery,
            showCamera: $showCamera,
            selectedImageData: $inputImageData
        )
        .sheet(item: $selectedPhoto) { photo in
            FullscreenPhotoViewer(photos: photos, initialPhoto: photo, title: "Galleria")
        }
        .onChange(of: inputImageData) {
            uploadSelectedImage()
        }
        #endif
        .task {
            await loadPhotos()
        }
    }
    
    private func loadPhotos() async {
        do {
            photos = try await APIClient.shared.getAppointmentPhotos(appointmentId: appointmentId)
        } catch {
            print("Error loading photos: \(error)")
        }
    }
    
    private func uploadSelectedImage() {
        #if os(iOS)
        guard let inputImage = inputImage else { return }
        guard let imageData = inputImage.jpegData(compressionQuality: 0.8) else { return }
        #else
        guard let imageData = inputImageData else { return }
        #endif
        
        isUploading = true
        Task {
            do {
                let newPhoto = try await APIClient.shared.uploadPhoto(appointmentId: appointmentId, image: imageData, type: "after")
                
                await MainActor.run {
                    photos.insert(newPhoto, at: 0)
                    #if os(iOS)
                    self.inputImage = nil
                    #else
                    self.inputImageData = nil
                    #endif
                    isUploading = false
                }
            } catch {
                print("Upload failed: \(error)")
                isUploading = false
            }
        }
    }
    
    private func deletePhoto(_ photo: Photo) {
        Task {
            do {
                try await APIClient.shared.deletePhoto(id: photo.id)
                await MainActor.run {
                    if let index = photos.firstIndex(of: photo) {
                        photos.remove(at: index)
                    }
                }
            } catch {
                print("Delete failed: \(error)")
            }
        }
    }
    
    private var formattedDate: String {
        DateFormatting.italianDate(from: appointment.date)
    }
    
    private func cleanPhoneNumber(_ phone: String) -> String {
        return phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    private func whatsappURL(phone: String) -> URL {
        let clean = cleanPhoneNumber(phone)
        let finalPhone = clean.count <= 10 ? "39\(clean)" : clean
        
        let clientName = appointment.client?.firstName ?? "Cliente"
        let salon = appointment.salon ?? salonManager.selectedSalon
        let salonName = salon?.name ?? "Onicotech"
        let location = (salon?.fullAddress.isEmpty == false) ? "\(salonName) (\(salon!.fullAddress))" : salonName
        
        let isStaffSender = salonManager.activeRole == "staff"
        let assignedStaffName = appointment.staffMember?.displayName
        
        var msg = ""
        if isStaffSender {
            let staffName = appointment.staffMember?.displayName ?? "la tua operatrice"
            msg = "Ciao \(clientName)! ✨\nSono \(staffName) di \(salonName).\nTi ricordo il tuo appuntamento per \(formattedDate) alle ore \(appointment.startTime).\n\n"
        } else if let staffName = assignedStaffName {
            msg = "Ciao \(clientName)! ✨\nTi ricordiamo il tuo appuntamento con la nostra operatrice \(staffName) presso \(salonName):\n\n📅 Data: \(formattedDate)\n⏰ Orario: ore \(appointment.startTime)\n"
        } else {
            msg = "Ciao \(clientName)! ✨\nTi ricordiamo il tuo appuntamento presso \(salonName):\n\n📅 Data: \(formattedDate)\n⏰ Orario: ore \(appointment.startTime)\n"
        }
        
        if let services = appointment.services, !services.isEmpty {
            let sList = services.map { $0.name }.joined(separator: ", ")
            msg += "💅 Trattamenti: \(sList)\n"
        }
        msg += "📍 Sede: \(location)\n"
        
        if let apptId = appointment.id {
            msg += "📲 Scheda e calendario: https://app.onicotech.it/book/\(apptId.uuidString.lowercased())\n"
        }
        
        if isStaffSender {
            let staffName = appointment.staffMember?.displayName ?? ""
            msg += "\nA presto, \(staffName)! 💅✨"
        } else {
            msg += "\nIl team di \(salonName) 💅✨"
        }
        
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://api.whatsapp.com/send?phone=\(finalPhone)&text=\(encoded)") ?? URL(string: "https://api.whatsapp.com/send?phone=\(finalPhone)")!
    }
    
    private func staffWhatsappURL(staff: SalonMember) -> URL {
        let clientName = appointment.client?.fullName ?? "Cliente"
        let clientPhone = appointment.client?.phone ?? ""
        let salon = appointment.salon ?? salonManager.selectedSalon
        let salonName = salon?.name ?? "Onicotech"
        
        var msg = "Ciao \(staff.displayName)! ✨\nTi è stato assegnato un appuntamento in salone:\n\n"
        msg += "👤 Cliente: \(clientName)\(clientPhone.isEmpty ? "" : " (" + clientPhone + ")")\n"
        msg += "📅 Data: \(formattedDate) ore \(appointment.startTime)\n"
        if let services = appointment.services, !services.isEmpty {
            let sList = services.map { $0.name }.joined(separator: ", ")
            msg += "💅 Trattamenti: \(sList)\n"
        }
        msg += "📍 Sede: \(salonName)\n"
        if let notes = appointment.notes, !notes.isEmpty {
            msg += "📝 Note: \(notes)\n"
        }
        if let apptId = appointment.id {
            msg += "📲 Scheda appuntamento: https://app.onicotech.it/book/\(apptId.uuidString.lowercased())\n"
        }
        msg += "\nBuon lavoro! 💅"
        
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://api.whatsapp.com/send?text=\(encoded)") ?? URL(string: "https://api.whatsapp.com/send")!
    }
}
