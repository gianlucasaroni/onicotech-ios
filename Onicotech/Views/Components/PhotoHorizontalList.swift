
import SwiftUI

struct PhotoHorizontalList: View {
    let photos: [Photo]
    let onPhotoSelected: (Photo) -> Void
    var isUploading: Bool = false
    
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
                                .frame(width: 80, height: 80)
                            ProgressView()
                        }
                    }
                    
                    ForEach(photos) { photo in
                        AsyncImage(url: URL(string: photo.thumbnailUrl ?? photo.url)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        onPhotoSelected(photo)
                                    }
                            case .failure:
                                Image(systemName: "photo")
                                    .frame(width: 80, height: 80)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
