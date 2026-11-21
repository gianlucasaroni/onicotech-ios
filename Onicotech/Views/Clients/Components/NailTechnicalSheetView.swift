import SwiftUI
import Kingfisher

// MARK: - Nail Technical Sheet View
/// Enhanced nail technical data display with photo timeline

struct NailTechnicalSheetView: View {
    let client: Client
    let nailPhotos: [Photo]
    let onPhotoSelected: ((Photo) -> Void)?
    let onEdit: () -> Void
    
    @State private var selectedTab: NailSheetTab = .info
    @State private var showingPhotoGallery = false
    
    enum NailSheetTab: String, CaseIterable {
        case info = "Dati"
        case photos = "Foto"
        case timeline = "Timeline"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with edit button
            HStack {
                Label("Scheda Tecnica Unghie", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    Haptics.play(.light)
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            
            // Tab picker
            Picker("Scheda", selection: $selectedTab) {
                ForEach(NailSheetTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Content based on tab
            switch selectedTab {
            case .info:
                nailInfoSection
            case .photos:
                nailPhotosSection
            case .timeline:
                nailTimelineSection
            }
        }
        .padding(.vertical, 8)
        .background(Color.systemBackgroundCompat)
    }
    
    // MARK: - Nail Info Section
    private var nailInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Nail Type
            if let nailType = client.nailType, !nailType.isEmpty {
                InfoRow(
                    icon: "sparkles",
                    label: "Tipologia Unghia",
                    value: nailType,
                    iconColor: .purple
                )
            }
            
            // Preferred Shape
            if let shape = client.preferredShape, !shape.isEmpty {
                InfoRow(
                    icon: "hand.raised",
                    label: "Forma Preferita",
                    value: shape,
                    iconColor: .blue
                )
            }
            
            // Allergies (highlighted)
            if let allergies = client.allergies, !allergies.isEmpty {
                AllergyAlert(allergies: allergies)
            }
            
            // Technical Notes
            if let techNotes = client.technicalNotes, !techNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Basi, Costruttore e Colori", systemImage: "paintpalette")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(techNotes)
                        .font(.subheadline)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Customer Tag
            if let tag = client.customerTag, !tag.isEmpty {
                HStack {
                    Label("Tag Profilo", systemImage: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(tag)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tagColor(tag).opacity(0.15))
                        .foregroundStyle(tagColor(tag))
                        .clipShape(Capsule())
                }
            }
            
            // Empty state
            if isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Scheda tecnica non compilata")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        onEdit()
                    } label: {
                        Text("Compila ora")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding()
    }
    
    // MARK: - Nail Photos Section
    private var nailPhotosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if nailPhotos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Nessuna foto unghie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                PhotoHorizontalList(
                    photos: nailPhotos,
                    isUploading: false,
                    size: 100,
                    onPhotoSelected: onPhotoSelected
                )
            }
        }
        .padding()
    }
    
    // MARK: - Nail Timeline Section
    private var nailTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if nailPhotos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Nessuna foto nella timeline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Carica foto prima/dopo per tracciare l'evoluzione")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Group photos by appointment
                let groupedPhotos = Dictionary(grouping: nailPhotos, by: { $0.appointmentId })
                let sortedAppointmentIds = groupedPhotos.keys.sorted { id1, id2 in
                    let d1 = groupedPhotos[id1]?.map(\.createdAt).max() ?? .distantPast
                    let d2 = groupedPhotos[id2]?.map(\.createdAt).max() ?? .distantPast
                    return d1 > d2
                }
                
                ForEach(sortedAppointmentIds, id: \.self) { appointmentId in
                    TimelineEntryView(photos: groupedPhotos[appointmentId] ?? [])
                }
            }
        }
        .padding()
    }
    
    private var isEmpty: Bool {
        (client.nailType?.isEmpty ?? true) &&
        (client.preferredShape?.isEmpty ?? true) &&
        (client.technicalNotes?.isEmpty ?? true) &&
        (client.customerTag?.isEmpty ?? true) &&
        (client.allergies?.isEmpty ?? true)
    }
    
    private func tagColor(_ tag: String) -> Color {
        switch tag.lowercased() {
        case "vip": return .orange
        case "nuova cliente", "nuova": return .purple
        case "fedele": return .green
        case "super puntuale", "puntuale": return .blue
        case "esigente": return .indigo
        default: return .secondary
        }
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Allergy Alert Component
struct AllergyAlert: View {
    let allergies: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ALLERGIE / SICUREZZA")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                Text(allergies)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Timeline Entry View
struct TimelineEntryView: View {
    let photos: [Photo]
    
    @State private var showingFullscreen = false
    @State private var selectedPhoto: Photo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                
                Text("Appuntamento")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Photo grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(photos) { photo in
                    Button {
                        selectedPhoto = photo
                        showingFullscreen = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            KFImage(URL(string: photo.thumbnailUrl))
                                .placeholder {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .aspectRatio(1, contentMode: .fill)
                                }
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Type badge
                            Image(systemName: badgeIconForType(photo.type))
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .offset(x: -6, y: 6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $selectedPhoto) { photo in
            FullscreenPhotoViewer(
                photos: photos,
                initialPhoto: photo,
                title: "Foto Unghie"
            )
        }
    }
    
    private func badgeIconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "before": return "arrow.left.circle.fill"
        case "after": return "arrow.right.circle.fill"
        default: return "photo.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        NailTechnicalSheetView(
            client: Client(
                firstName: "Mario",
                lastName: "Rossi",
                nailType: "Standard / Naturale",
                allergies: "HEMA-Free, Acrilati",
                preferredShape: "Mandorla",
                technicalNotes: "Base coat: OPI Natural Nail Base Coat\nBuilder: IBD Builder Gel Clear\nColore: OPI Bubble Bath",
                customerTag: "Fedele"
            ),
            nailPhotos: [],
            onPhotoSelected: { _ in },
            onEdit: {}
        )
        .navigationTitle("Scheda Cliente")
    }
}
