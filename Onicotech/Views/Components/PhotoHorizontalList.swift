
import SwiftUI
import Kingfisher

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
                        KFImage(URL(string: photo.fullThumbnailUrl))
                            .placeholder {
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                onPhotoSelected(photo)
                            }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
