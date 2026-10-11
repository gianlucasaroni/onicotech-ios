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
                        Text("Totale")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(appointment.formattedTotalPrice)
                            .fontWeight(.semibold)
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
        
        var msg = "Ciao \(appointment.client?.firstName ?? "Cliente"),\nti ricordo il tuo appuntamento del \(formattedDate) alle \(appointment.startTime)."
        
        if let services = appointment.services, !services.isEmpty {
            msg += "\n\nServizi:"
            for service in services {
                msg += "\n- \(service.name) (\(service.formattedPrice))"
            }
        }
        
        msg += "\n\nA presto!"
        
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(finalPhone)?text=\(encoded)") ?? URL(string: "https://wa.me/\(finalPhone)")!
    }
}
