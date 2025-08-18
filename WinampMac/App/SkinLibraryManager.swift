import Foundation
import SwiftUI
import CloudKit
import Combine

/// Comprehensive Skin Library Manager with iCloud sync, search, and organization
/// Manages the user's collection of Winamp skins with metadata and thumbnails
@MainActor
final class SkinLibraryManager: ObservableObject {
    
    @Published var skins: [SkinLibraryItem] = []
    @Published var isLoading = false
    @Published var isCloudSyncEnabled = false
    @Published var isSyncing = false
    @Published var cloudSyncStatus = "Not synced"
    @Published var searchResults: [SkinLibraryItem] = []
    
    private let fileManager = FileManager.default
    private let cloudKitContainer: CKContainer
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    
    // Library paths
    private lazy var libraryURL: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WinampMac/Skins")
    }()
    
    private lazy var thumbnailsURL: URL = {
        return libraryURL.appendingPathComponent("Thumbnails")
    }()
    
    private lazy var metadataURL: URL = {
        return libraryURL.appendingPathComponent("metadata.json")
    }()
    
    init() {
        self.cloudKitContainer = CKContainer(identifier: "iCloud.com.winamp.mac")
        self.privateDatabase = cloudKitContainer.privateCloudDatabase
        
        setupLibraryDirectories()
        loadSkins()
        setupCloudSync()
    }
    
    // MARK: - Public Methods
    
    func loadSkins() {
        Task {
            await loadSkinsFromDisk()
        }
    }
    
    func importSkin(from url: URL) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Copy skin to library
        let skinName = url.deletingPathExtension().lastPathComponent
        let destinationURL = libraryURL.appendingPathComponent("\(skinName).wsz")
        
        // Ensure unique filename
        let finalURL = generateUniqueURL(for: destinationURL)
        
        try fileManager.copyItem(at: url, to: finalURL)
        
        // Create library item
        let libraryItem = try await createLibraryItem(from: finalURL)
        
        // Add to collection
        skins.append(libraryItem)
        
        // Save metadata
        saveMetadata()
        
        // Sync to iCloud if enabled
        if isCloudSyncEnabled {
            await syncSkinToCloud(libraryItem)
        }
    }
    
    func deleteSkin(_ skin: SkinLibraryItem) async {
        // Remove from array
        skins.removeAll { $0.id == skin.id }
        
        // Delete files
        do {
            try fileManager.removeItem(at: skin.fileURL)
            
            // Delete thumbnail if exists
            let thumbnailURL = thumbnailsURL.appendingPathComponent("\(skin.id.uuidString).png")
            if fileManager.fileExists(atPath: thumbnailURL.path) {
                try fileManager.removeItem(at: thumbnailURL)
            }
            
            // Save updated metadata
            saveMetadata()
            
            // Delete from iCloud if synced
            if skin.isCloudSynced {
                await deleteSkinFromCloud(skin)
            }
            
        } catch {
            print("Failed to delete skin: \(error)")
        }
    }
    
    func duplicateSkin(_ skin: SkinLibraryItem) async {
        do {
            let duplicateName = "\(skin.name) Copy"
            let duplicateURL = libraryURL.appendingPathComponent("\(duplicateName).wsz")
            let finalURL = generateUniqueURL(for: duplicateURL)
            
            try fileManager.copyItem(at: skin.fileURL, to: finalURL)
            
            let duplicateItem = try await createLibraryItem(from: finalURL)
            skins.append(duplicateItem)
            
            saveMetadata()
            
        } catch {
            print("Failed to duplicate skin: \(error)")
        }
    }
    
    func recordUsage(for skin: SkinLibraryItem) {
        if let index = skins.firstIndex(where: { $0.id == skin.id }) {
            skins[index].usageCount += 1
            skins[index].lastUsed = Date()
            saveMetadata()
        }
    }
    
    func toggleFavorite(for skin: SkinLibraryItem) {
        if let index = skins.firstIndex(where: { $0.id == skin.id }) {
            skins[index].isFavorite.toggle()
            saveMetadata()
        }
    }
    
    func searchSkins(query: String) {
        if query.isEmpty {
            searchResults = []
        } else {
            searchResults = skins.filter { skin in
                skin.name.localizedCaseInsensitiveContains(query) ||
                skin.author.localizedCaseInsensitiveContains(query) ||
                skin.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
    }
    
    func skinCount(for category: SkinCategory) -> Int {
        if category == .all {
            return skins.count
        }
        return skins.filter { $0.category == category }.count
    }
    
    // MARK: - Private Methods
    
    private func setupLibraryDirectories() {
        do {
            try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create library directories: \(error)")
        }
    }
    
    private func loadSkinsFromDisk() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load existing metadata
        var existingMetadata: [String: SkinLibraryItem] = [:]
        
        if fileManager.fileExists(atPath: metadataURL.path) {
            do {
                let data = try Data(contentsOf: metadataURL)
                let items = try JSONDecoder().decode([SkinLibraryItem].self, from: data)
                existingMetadata = Dictionary(uniqueKeysWithValues: items.map { ($0.fileURL.lastPathComponent, $0) })
            } catch {
                print("Failed to load existing metadata: \(error)")
            }
        }
        
        // Scan directory for .wsz files
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: libraryURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "wsz" }
            
            var loadedSkins: [SkinLibraryItem] = []
            
            for fileURL in fileURLs {
                let filename = fileURL.lastPathComponent
                
                if let existingItem = existingMetadata[filename] {
                    // Use existing metadata
                    loadedSkins.append(existingItem)
                } else {
                    // Create new library item
                    do {
                        let libraryItem = try await createLibraryItem(from: fileURL)
                        loadedSkins.append(libraryItem)
                    } catch {
                        print("Failed to create library item for \(filename): \(error)")
                    }
                }
            }
            
            skins = loadedSkins
            saveMetadata()
            
        } catch {
            print("Failed to scan skin library: \(error)")
        }
    }
    
    private func createLibraryItem(from fileURL: URL) async throws -> SkinLibraryItem {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let dateAdded = attributes[.creationDate] as? Date ?? Date()
        
        // Extract basic info from filename
        let name = fileURL.deletingPathExtension().lastPathComponent
        
        // Analyze skin contents for metadata
        let metadata = try await analyzeSkinContents(at: fileURL)
        
        return SkinLibraryItem(
            id: UUID(),
            name: metadata.name.isEmpty ? name : metadata.name,
            author: metadata.author,
            fileURL: fileURL,
            fileSize: fileSize,
            dateAdded: dateAdded,
            tags: metadata.tags,
            category: categorizeBasedOnMetadata(metadata),
            dominantColorScheme: metadata.dominantColorScheme,
            usageCount: 0,
            isFavorite: false,
            isCloudSynced: false,
            lastUsed: nil
        )
    }
    
    private func analyzeSkinContents(at url: URL) async throws -> SkinMetadata {
        // Load and analyze the .wsz file
        let skinData = try Data(contentsOf: url)
        let unzippedData = try ZipArchive.unzip(data: skinData)
        
        var name = ""
        var author = "Unknown"
        var tags: Set<String> = []
        var dominantColorScheme: ColorScheme = .dark
        
        // Look for pledit.txt or readme.txt for metadata
        for (filename, data) in unzippedData {
            let lowercaseFilename = filename.lowercased()
            
            if lowercaseFilename.contains("pledit.txt") || lowercaseFilename.contains("readme") {
                if let content = String(data: data, encoding: .utf8) {
                    let metadata = parseSkinTextFile(content)
                    if !metadata.name.isEmpty { name = metadata.name }
                    if !metadata.author.isEmpty { author = metadata.author }
                    tags.formUnion(metadata.tags)
                }
            }
            
            // Analyze main.bmp/main.png for color scheme
            if lowercaseFilename.contains("main.") && (lowercaseFilename.hasSuffix(".bmp") || lowercaseFilename.hasSuffix(".png")) {
                if let image = NSImage(data: data) {
                    dominantColorScheme = analyzeImageColorScheme(image)
                }
            }
        }
        
        return SkinMetadata(
            name: name,
            author: author,
            tags: tags,
            dominantColorScheme: dominantColorScheme
        )
    }
    
    private func parseSkinTextFile(_ content: String) -> (name: String, author: String, tags: Set<String>) {
        var name = ""
        var author = ""
        var tags: Set<String> = []
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for common patterns
            if trimmedLine.lowercased().hasPrefix("name:") || trimmedLine.lowercased().hasPrefix("title:") {
                name = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.lowercased().hasPrefix("author:") || trimmedLine.lowercased().hasPrefix("by:") {
                author = String(trimmedLine.dropFirst(trimmedLine.lowercased().hasPrefix("author:") ? 7 : 3)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.lowercased().hasPrefix("style:") || trimmedLine.lowercased().hasPrefix("genre:") {
                let tag = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                tags.insert(tag)
            }
        }
        
        // Extract additional tags from content
        let keywords = ["classic", "modern", "dark", "light", "minimal", "colorful", "gaming", "abstract"]
        for keyword in keywords {
            if content.localizedCaseInsensitiveContains(keyword) {
                tags.insert(keyword)
            }
        }
        
        return (name: name, author: author, tags: tags)
    }
    
    private func analyzeImageColorScheme(_ image: NSImage) -> ColorScheme {
        // Simplified color analysis
        // In a real implementation, this would analyze the image pixels
        // to determine if it's predominantly light or dark
        
        let imageRep = image.representations.first as? NSBitmapImageRep
        // Analyze bitmap data for brightness
        // For now, return a default
        return .dark
    }
    
    private func categorizeBasedOnMetadata(_ metadata: SkinMetadata) -> SkinCategory {
        let tags = metadata.tags.map { $0.lowercased() }
        
        if tags.contains("gaming") || tags.contains("game") { return .gaming }
        if tags.contains("classic") || tags.contains("retro") { return .classic }
        if tags.contains("modern") || tags.contains("contemporary") { return .modern }
        if tags.contains("minimal") || tags.contains("simple") { return .minimal }
        if tags.contains("colorful") || tags.contains("rainbow") { return .colorful }
        if tags.contains("dark") { return .dark }
        if tags.contains("light") { return .light }
        if tags.contains("abstract") || tags.contains("artistic") { return .abstract }
        
        return .custom
    }
    
    private func generateUniqueURL(for url: URL) -> URL {
        var uniqueURL = url
        var counter = 1
        
        while fileManager.fileExists(atPath: uniqueURL.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let extension = url.pathExtension
            let directory = url.deletingLastPathComponent()
            
            uniqueURL = directory.appendingPathComponent("\(nameWithoutExtension) (\(counter)).\(extension)")
            counter += 1
        }
        
        return uniqueURL
    }
    
    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(skins)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }
    
    // MARK: - iCloud Sync
    
    private func setupCloudSync() {
        // Check if iCloud is available
        cloudKitContainer.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                switch accountStatus {
                case .available:
                    self?.isCloudSyncEnabled = true
                    self?.cloudSyncStatus = "Ready to sync"
                case .noAccount:
                    self?.cloudSyncStatus = "No iCloud account"
                case .restricted:
                    self?.cloudSyncStatus = "iCloud restricted"
                case .couldNotDetermine:
                    self?.cloudSyncStatus = "iCloud status unknown"
                @unknown default:
                    self?.cloudSyncStatus = "iCloud unavailable"
                }
            }
        }
    }
    
    private func syncSkinToCloud(_ skin: SkinLibraryItem) async {
        guard isCloudSyncEnabled else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Create CKRecord for skin
            let record = CKRecord(recordType: "WinampSkin")
            record["name"] = skin.name
            record["author"] = skin.author
            record["tags"] = Array(skin.tags)
            record["category"] = skin.category.rawValue
            record["dateAdded"] = skin.dateAdded
            record["usageCount"] = skin.usageCount
            record["isFavorite"] = skin.isFavorite
            
            // Upload skin file as asset
            let asset = CKAsset(fileURL: skin.fileURL)
            record["skinFile"] = asset
            
            // Save to CloudKit
            let _ = try await privateDatabase.save(record)
            
            // Update local item
            if let index = skins.firstIndex(where: { $0.id == skin.id }) {
                skins[index].isCloudSynced = true
                saveMetadata()
            }
            
            cloudSyncStatus = "Synced"
            
        } catch {
            print("Failed to sync skin to iCloud: \(error)")
            cloudSyncStatus = "Sync failed"
        }
    }
    
    private func deleteSkinFromCloud(_ skin: SkinLibraryItem) async {
        guard isCloudSyncEnabled else { return }
        
        // Implementation would delete from CloudKit
        print("Deleting skin from iCloud: \(skin.name)")
    }
    
    private func downloadSkinsFromCloud() async {
        guard isCloudSyncEnabled else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let query = CKQuery(recordType: "WinampSkin", predicate: NSPredicate(value: true))
            let result = try await privateDatabase.records(matching: query)
            
            for (recordID, record) in result.matchResults {
                switch record {
                case .success(let record):
                    await processCloudSkinRecord(record)
                case .failure(let error):
                    print("Failed to process record \(recordID): \(error)")
                }
            }
            
            cloudSyncStatus = "Synced"
            
        } catch {
            print("Failed to download skins from iCloud: \(error)")
            cloudSyncStatus = "Download failed"
        }
    }
    
    private func processCloudSkinRecord(_ record: CKRecord) async {
        // Implementation would process CloudKit record and download skin file
        print("Processing cloud skin record: \(record["name"] ?? "Unknown")")
    }
}

// MARK: - Supporting Types

struct SkinLibraryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var author: String
    let fileURL: URL
    let fileSize: Int64
    let dateAdded: Date
    var tags: Set<String>
    var category: SkinCategory
    var dominantColorScheme: ColorScheme
    var usageCount: Int
    var isFavorite: Bool
    var isCloudSynced: Bool
    var lastUsed: Date?
    
    var isRecent: Bool {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return dateAdded >= weekAgo
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, author, fileURL, fileSize, dateAdded, tags, category
        case dominantColorScheme, usageCount, isFavorite, isCloudSynced, lastUsed
    }
}

struct SkinMetadata {
    let name: String
    let author: String
    let tags: Set<String>
    let dominantColorScheme: ColorScheme
}

// MARK: - Extensions

extension SkinCategory: Codable {
    enum SkinCategory: String, CaseIterable, Codable {
        case all = "all"
        case classic = "classic"
        case modern = "modern"
        case gaming = "gaming"
        case abstract = "abstract"
        case minimal = "minimal"
        case colorful = "colorful"
        case dark = "dark"
        case light = "light"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .all: return "All Skins"
            case .classic: return "Classic"
            case .modern: return "Modern"
            case .gaming: return "Gaming"
            case .abstract: return "Abstract"
            case .minimal: return "Minimal"
            case .colorful: return "Colorful"
            case .dark: return "Dark"
            case .light: return "Light"
            case .custom: return "Custom"
            }
        }
        
        var iconName: String {
            switch self {
            case .all: return "square.grid.3x3"
            case .classic: return "clock"
            case .modern: return "sparkles"
            case .gaming: return "gamecontroller"
            case .abstract: return "paintbrush"
            case .minimal: return "circle"
            case .colorful: return "paintpalette"
            case .dark: return "moon"
            case .light: return "sun.max"
            case .custom: return "wrench.and.screwdriver"
            }
        }
    }
}

extension ColorScheme: Codable {}