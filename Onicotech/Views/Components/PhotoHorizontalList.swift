import SwiftUI
import Kingfisher

// MARK: - ViewablePhoto Protocol

/// Shared protocol for any photo type that can be viewed in galleries and lists.
protocol ViewablePhoto: Identifiable, Hashable {
    var id: UUID { get }
    var thumbnailUrl: String { get }
    var originalUrl: String { get }
}

// Conformances
extension Photo: ViewablePhoto {
    var thumbnailUrl: String { fullThumbnailUrl }
    var originalUrl: String { fullOriginalUrl }
}

extension ExpensePhoto: ViewablePhoto {}

// MARK: - Photo Horizontal List (Generic)

struct PhotoHorizontalList<P: ViewablePhoto>: View {
    let photos: [P]
    let onPhotoSelected: ((P) -> Void)?
    let onPhotoDeleted: ((P) -> Void)?
    var isUploading: Bool = false
    var size: CGFloat = 80
    
    init(photos: [P], isUploading: Bool = false, size: CGFloat = 80,
         onPhotoSelected: ((P) -> Void)? = nil, onPhotoDeleted: ((P) -> Void)? = nil) {
        self.photos = photos
        self.isUploading = isUploading
        self.size = size
        self.onPhotoSelected = onPhotoSelected
        self.onPhotoDeleted = onPhotoDeleted
    }
    
    var body: some View {
        if photos.isEmpty && !isUploading {
            Text("Nessuna foto")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if isUploading {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: size, height: size)
                            ProgressView()
                        }
                    }
                    
                    ForEach(photos) { photo in
                        ZStack(alignment: .topTrailing) {
                            KFImage(URL(string: photo.thumbnailUrl))
                                .placeholder {
                                    ProgressView()
                                        .frame(width: size, height: size)
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    onPhotoSelected?(photo)
                                }
                            
                            if let onPhotoDeleted {
                                Button {
                                    onPhotoDeleted(photo)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white, .red)
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Fullscreen Photo Viewer (Generic)

struct FullscreenPhotoViewer<P: ViewablePhoto>: View {
    let photos: [P]
    let title: String
    @State private var selection: P
    @Environment(\.dismiss) private var dismiss
    
    init(photos: [P], initialPhoto: P, title: String = "Galleria") {
        self.photos = photos
        self.title = title
        self._selection = State(initialValue: initialPhoto)
    }
    
    var body: some View {
        NavigationStack {
            #if os(iOS)
            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    ZoomableRemoteImageView(url: URL(string: photo.originalUrl))
                        .tag(photo)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(Color.black)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #else
            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    KFImage(URL(string: photo.originalUrl))
                        .resizable()
                        .scaledToFit()
                        .tag(photo)
                }
            }
            .background(Color.black)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            #endif
        }
        .preferredColorScheme(.dark)
    }
}

#if os(iOS)
struct ZoomableRemoteImageView: UIViewRepresentable {
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
        
        if let url {
            imageView.kf.indicatorType = .activity
            imageView.kf.setImage(with: url)
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
#endif

// MARK: - Photo Source Picker Modifier

struct PhotoSourcePickerModifier: ViewModifier {
    @Binding var showSourcePicker: Bool
    @Binding var showGallery: Bool
    @Binding var showCamera: Bool
    #if os(iOS)
    @Binding var selectedImage: UIImage?
    #else
    @Binding var selectedImageData: Data?
    #endif
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("Scegli origine foto", isPresented: $showSourcePicker, titleVisibility: .visible) {
                Button("Fotocamera") { showCamera = true }
                Button("Galleria") { showGallery = true }
                Button("Annulla", role: .cancel) {}
            }
            .sheet(isPresented: $showGallery) {
                #if os(iOS)
                ImagePicker(image: $selectedImage)
                #else
                ImagePicker(imageData: $selectedImageData)
                #endif
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $selectedImage)
            }
            #endif
    }
}

extension View {
    #if os(iOS)
    func photoSourcePicker(
        showSourcePicker: Binding<Bool>,
        showGallery: Binding<Bool>,
        showCamera: Binding<Bool>,
        selectedImage: Binding<UIImage?>
    ) -> some View {
        modifier(PhotoSourcePickerModifier(
            showSourcePicker: showSourcePicker,
            showGallery: showGallery,
            showCamera: showCamera,
            selectedImage: selectedImage
        ))
    }
    #else
    func photoSourcePicker(
        showSourcePicker: Binding<Bool>,
        showGallery: Binding<Bool>,
        showCamera: Binding<Bool>,
        selectedImageData: Binding<Data?>
    ) -> some View {
        modifier(PhotoSourcePickerModifier(
            showSourcePicker: showSourcePicker,
            showGallery: showGallery,
            showCamera: showCamera,
            selectedImageData: selectedImageData
        ))
    }
    #endif
}
