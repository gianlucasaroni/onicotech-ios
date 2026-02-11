import SwiftUI

struct AppointmentDetailView: View {
    let appointmentId: UUID
    let initialAppointment: Appointment // Fallback if not found in VM list (e.g. filtered out)
    var viewModel: AppointmentViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // Dynamic lookup for live updates
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

    var body: some View {
        List {
            // ... (keep sections) ...
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
                            // Call Button
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

                            // WhatsApp Button
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
                if photos.isEmpty {
                    Text("Nessuna foto caricata")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if isUploading {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 100, height: 100)
                                    ProgressView()
                                }
                            }
                            
                            ForEach(photos) { photo in
                                // List uses Thumbnail (fallback to original if missing)
                                AsyncImage(url: URL(string: photo.thumbnailUrl ?? photo.url)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 100, height: 100)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture {
                                                selectedPhoto = photo
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deletePhoto(photo)
                                                } label: {
                                                    Label("Elimina", systemImage: "trash")
                                                }
                                            }
                                    case .failure:
                                        Image(systemName: "photo")
                                            .frame(width: 100, height: 100)
                                            .background(Color.gray.opacity(0.1))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Button {
                    showImagePicker = true
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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoGalleryViewer(photos: photos, initialPhoto: photo)
        }
        .onChange(of: inputImage) { _ in
            uploadSelectedImage()
        }
        .task {
            await loadPhotos()
        }
    }
    
    @State private var photos: [Photo] = []
    @State private var selectedPhoto: Photo?
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var isUploading = false
    
    private func loadPhotos() async {
        do {
            photos = try await APIClient.shared.getAppointmentPhotos(appointmentId: appointmentId)
        } catch {
            print("Error loading photos: \(error)")
        }
    }
    
    private func uploadSelectedImage() {
        guard let inputImage = inputImage else { return }
        guard let imageData = inputImage.jpegData(compressionQuality: 0.8) else { return }
        
        isUploading = true
        Task {
            do {
                // Determine type based on date? Or prompt user? For now default to "result" (after)
                // Or "other".
                // Simple implementation: just upload.
                let newPhoto = try await APIClient.shared.uploadPhoto(appointmentId: appointmentId, image: imageData, type: "after")
                
                // Add to list immediately
                await MainActor.run {
                    photos.insert(newPhoto, at: 0)
                    self.inputImage = nil
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
        let months = ["", "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
                      "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"]
        let components = appointment.date.split(separator: "-")
        guard components.count == 3,
              let day = Int(components[2]),
              let month = Int(components[1]),
              month >= 1, month <= 12 else { return appointment.date }
        return "\(day) \(months[month]) \(components[0])"
    }
    
    private func cleanPhoneNumber(_ phone: String) -> String {
        return phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    private func whatsappURL(phone: String) -> URL {
        let clean = cleanPhoneNumber(phone)
        // Assume Italy (+39) if no prefix is present (simple heuristic)
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

struct PhotoGalleryViewer: View {
    let photos: [Photo]
    @State private var selection: Photo
    @Environment(\.dismiss) private var dismiss
    
    init(photos: [Photo], initialPhoto: Photo) {
        self.photos = photos
        self._selection = State(initialValue: initialPhoto)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    ZoomableImageView(url: URL(string: photo.url))
                        .tag(photo)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(Color.black)
            .navigationTitle("Galleria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let url: URL?
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
        
        context.coordinator.imageView = imageView
        
        // Load Image
        if let url {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            imageView.image = image
                        }
                    }
                } catch {
                    print("Failed to load image for zoom: \(error)")
                }
            }
        }
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
    }
}
