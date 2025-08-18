import SwiftUI
import AppKit

/// Individual skin item in the library grid with preview and metadata
struct SkinGridItem: View {
    let skin: SkinLibraryItem
    let isSelected: Bool
    let isHovered: Bool
    let size: GridItemSize
    
    @State private var thumbnail: NSImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            thumbnailView
                .frame(
                    width: size.thumbnailSize.width,
                    height: size.thumbnailSize.height
                )
                .background(Color.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .overlay(alignment: .topTrailing) {
                    statusBadges
                }
                .overlay(alignment: .bottomLeading) {
                    if isHovered {
                        quickActionButtons
                    }
                }
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text("by \(skin.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !skin.tags.isEmpty {
                    HStack {
                        ForEach(Array(skin.tags.prefix(3)), id: \.self) { tag in
                            tagView(tag)
                        }
                        
                        if skin.tags.count > 3 {
                            Text("+\(skin.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                metadataFooter
            }
            .frame(width: size.thumbnailSize.width, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onAppear {
            loadThumbnail()
        }
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if isLoadingThumbnail {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                placeholderThumbnail
            }
        }
    }
    
    private var placeholderThumbnail: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.4),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(skin.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    // MARK: - Status Badges
    
    @ViewBuilder
    private var statusBadges: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if skin.isCloudSynced {
                Badge(icon: "cloud.fill", color: .blue)
            }
            
            if skin.isFavorite {
                Badge(icon: "heart.fill", color: .red)
            }
            
            if skin.usageCount > 10 {
                Badge(icon: "star.fill", color: .yellow)
            }
            
            if skin.isRecent {
                Badge(icon: "sparkles", color: .green)
            }
        }
        .padding(8)
    }
    
    // MARK: - Quick Action Buttons
    
    private var quickActionButtons: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "play.fill",
                action: { applySkin() }
            )
            
            QuickActionButton(
                icon: "eye.fill",
                action: { previewSkin() }
            )
            
            QuickActionButton(
                icon: skin.isFavorite ? "heart.fill" : "heart",
                action: { toggleFavorite() }
            )
        }
        .padding(8)
    }
    
    // MARK: - Metadata Footer
    
    private var metadataFooter: some View {
        HStack {
            // File size
            Text(formatFileSize(skin.fileSize))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Usage count
            if skin.usageCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text("\(skin.usageCount)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            // Date added
            Text(formatDate(skin.dateAdded))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.2))
            .foregroundColor(.accentColor)
            .cornerRadius(4)
    }
    
    // MARK: - Actions
    
    private func loadThumbnail() {
        guard thumbnail == nil && !isLoadingThumbnail else { return }
        
        isLoadingThumbnail = true
        
        Task {
            do {
                let generatedThumbnail = try await SkinThumbnailGenerator.generateThumbnail(
                    for: skin,
                    size: size.thumbnailSize
                )
                
                await MainActor.run {
                    self.thumbnail = generatedThumbnail
                    self.isLoadingThumbnail = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingThumbnail = false
                }
                print("Failed to generate thumbnail for \(skin.name): \(error)")
            }
        }
    }
    
    private func applySkin() {
        // Notify parent to apply this skin
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplySkinRequested"),
            object: skin
        )
    }
    
    private func previewSkin() {
        // Notify parent to preview this skin
        NotificationCenter.default.post(
            name: NSNotification.Name("PreviewSkinRequested"),
            object: skin
        )
    }
    
    private func toggleFavorite() {
        // Toggle favorite status
        NotificationCenter.default.post(
            name: NSNotification.Name("ToggleSkinFavorite"),
            object: skin
        )
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct Badge: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(color)
            .clipShape(Circle())
            .shadow(radius: 2)
    }
}

struct QuickActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Skin Thumbnail Generator

actor SkinThumbnailGenerator {
    private static let cache = NSCache<NSString, NSImage>()
    
    static func generateThumbnail(for skin: SkinLibraryItem, size: CGSize) async throws -> NSImage {
        let cacheKey = "\(skin.id)-\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Generate new thumbnail
        let thumbnail = try await generateNewThumbnail(for: skin, size: size)
        
        // Cache the result
        cache.setObject(thumbnail, forKey: cacheKey)
        
        return thumbnail
    }
    
    private static func generateNewThumbnail(for skin: SkinLibraryItem, size: CGSize) async throws -> NSImage {
        // Load the skin data
        let skinData = try Data(contentsOf: skin.fileURL)
        let unzippedData = try ZipArchive.unzip(data: skinData)
        
        // Look for main.bmp or main.png
        var mainImageData: Data?
        
        for (filename, data) in unzippedData {
            if filename.lowercased().contains("main.") &&
               (filename.lowercased().hasSuffix(".bmp") || filename.lowercased().hasSuffix(".png")) {
                mainImageData = data
                break
            }
        }
        
        guard let imageData = mainImageData,
              let sourceImage = NSImage(data: imageData) else {
            // Create a placeholder thumbnail
            return createPlaceholderThumbnail(for: skin.name, size: size)
        }
        
        // Resize to thumbnail size
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        sourceImage.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    private static func createPlaceholderThumbnail(for name: String, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Draw gradient background
        let gradient = NSGradient(
            colors: [
                NSColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0),
                NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
            ]
        )
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // Draw skin name
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.width * 0.08),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        
        let attributedString = NSAttributedString(string: name, attributes: attributes)
        let stringSize = attributedString.size()
        let drawRect = NSRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2,
            width: stringSize.width,
            height: stringSize.height
        )
        
        attributedString.draw(in: drawRect)
        
        image.unlockFocus()
        
        return image
    }
}

// MARK: - Preview Support

struct SkinGridItem_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSkin = SkinLibraryItem(
            id: UUID(),
            name: "Sample Skin",
            author: "John Doe",
            fileURL: URL(fileURLWithPath: "/tmp/sample.wsz"),
            fileSize: 1024 * 1024,
            dateAdded: Date(),
            tags: ["classic", "blue", "retro"],
            category: .classic,
            dominantColorScheme: .dark,
            usageCount: 5,
            isFavorite: true,
            isCloudSynced: true
        )
        
        HStack {
            SkinGridItem(
                skin: sampleSkin,
                isSelected: false,
                isHovered: false,
                size: .medium
            )
            
            SkinGridItem(
                skin: sampleSkin,
                isSelected: true,
                isHovered: true,
                size: .medium
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}