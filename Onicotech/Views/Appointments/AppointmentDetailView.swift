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
        case .rescheduled: return .orange
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
                            .background(statusColor.opacity(0.1))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Client
            if let client = appointment.client {
                Section("Cliente") {
                    Label(client.fullName, systemImage: "person")
                    
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
