import SwiftUI
import AppKit

// MARK: - Supporting Views for the Demo App

/// Cloud Sync Settings View
struct CloudSyncSettingsView: View {
    @EnvironmentObject private var skinLibrary: SkinLibraryManager
    
    @State private var isEnabled = false
    @State private var syncOnWiFiOnly = true
    @State private var autoDownloadSkins = false
    @State private var maxCloudStorage = 1000 // MB
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("iCloud Sync Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable iCloud Sync", isOn: $isEnabled)
                    .onChange(of: isEnabled) { enabled in
                        if enabled {
                            skinLibrary.enableiCloudSync()
                        }
                    }
                
                if isEnabled {
                    Group {
                        Toggle("Sync only on Wi-Fi", isOn: $syncOnWiFiOnly)
                        
                        Toggle("Auto-download new skins", isOn: $autoDownloadSkins)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Max Cloud Storage")
                            
                            HStack {
                                Slider(value: Binding(
                                    get: { Double(maxCloudStorage) },
                                    set: { maxCloudStorage = Int($0) }
                                ), in: 100...5000, step: 100) {
                                    Text("Storage Limit")
                                }
                                
                                Text("\(maxCloudStorage) MB")
                                    .frame(width: 80, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.leading)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Sync Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(syncStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(skinLibrary.cloudSyncStatus)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if skinLibrary.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            if isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync Actions")
                        .font(.headline)
                    
                    HStack {
                        Button("Sync Now") {
                            // Trigger manual sync
                        }
                        .disabled(skinLibrary.isSyncing)
                        
                        Button("Clear Cloud Data") {
                            // Clear all cloud data
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismissView()
                }
                
                Button("Save") {
                    saveSettings()
                    dismissView()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
    
    private var syncStatusColor: Color {
        switch skinLibrary.cloudSyncStatus {
        case "Synced", "Ready to sync":
            return .green
        case "Syncing":
            return .orange
        default:
            return .red
        }
    }
    
    private func saveSettings() {
        // Save cloud sync settings
        UserDefaults.standard.set(isEnabled, forKey: "CloudSyncEnabled")
        UserDefaults.standard.set(syncOnWiFiOnly, forKey: "CloudSyncWiFiOnly")
        UserDefaults.standard.set(autoDownloadSkins, forKey: "CloudAutoDownload")
        UserDefaults.standard.set(maxCloudStorage, forKey: "CloudMaxStorage")
    }
    
    private func dismissView() {
        // Close the sheet
        if let window = NSApp.keyWindow {
            window.close()
        }
    }
}

/// Skin Preview View
struct SkinPreviewView: View {
    let skin: SkinLibraryItem
    
    @State private var previewImage: NSImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(skin.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("by \(skin.author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Apply Skin") {
                    applySkin()
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Preview image
            Group {
                if isLoading {
                    ProgressView("Loading preview...")
                        .frame(height: 200)
                } else if let image = previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .background(Color.black)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Text("Preview not available")
                                .foregroundColor(.secondary)
                        )
                }
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                metadataRow("File Size", value: formatFileSize(skin.fileSize))
                metadataRow("Date Added", value: DateFormatter.localizedString(from: skin.dateAdded, dateStyle: .medium, timeStyle: .none))
                metadataRow("Category", value: skin.category.displayName)
                metadataRow("Color Scheme", value: skin.dominantColorScheme == .dark ? "Dark" : "Light")
                
                if !skin.tags.isEmpty {
                    metadataRow("Tags", value: Array(skin.tags.prefix(5)).joined(separator: ", "))
                }
                
                if skin.usageCount > 0 {
                    metadataRow("Usage Count", value: "\(skin.usageCount) times")
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadPreview()
        }
    }
    
    @ViewBuilder
    private func metadataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .font(.caption)
    }
    
    private func loadPreview() {
        Task {
            do {
                let thumbnail = try await SkinThumbnailGenerator.generateThumbnail(
                    for: skin,
                    size: CGSize(width: 300, height: 200)
                )
                
                await MainActor.run {
                    self.previewImage = thumbnail
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func applySkin() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplySkinRequested"),
            object: skin
        )
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Skin Info View
struct SkinInfoView: View {
    let skin: SkinLibraryItem
    
    @State private var skinContents: [String] = []
    @State private var isLoadingContents = true
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with actions
                HStack {
                    VStack(alignment: .leading) {
                        Text(skin.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("by \(skin.author)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Button("Show in Finder") {
                            showInFinder()
                        }
                        
                        Button("Export...") {
                            exportSkin()
                        }
                    }
                }
                
                Divider()
                
                // Detailed information
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        infoSection("File Information", content: fileInfoContent)
                        infoSection("Metadata", content: metadataContent)
                        infoSection("Usage Statistics", content: usageStatsContent)
                        
                        if !skinContents.isEmpty {
                            infoSection("Skin Contents", content: skinContentsView)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadSkinContents()
        }
    }
    
    @ViewBuilder
    private func infoSection(_ title: String, content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
                .padding(.leading)
        }
    }
    
    @ViewBuilder
    private var fileInfoContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            infoRow("File Path", value: skin.fileURL.path)
            infoRow("File Size", value: formatFileSize(skin.fileSize))
            infoRow("Date Added", value: DateFormatter.localizedString(from: skin.dateAdded, dateStyle: .full, timeStyle: .short))
            
            if let lastUsed = skin.lastUsed {
                infoRow("Last Used", value: DateFormatter.localizedString(from: lastUsed, dateStyle: .medium, timeStyle: .short))
            }
        }
    }
    
    @ViewBuilder
    private var metadataContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            infoRow("Category", value: skin.category.displayName)
            infoRow("Color Scheme", value: skin.dominantColorScheme == .dark ? "Dark" : "Light")
            infoRow("Is Favorite", value: skin.isFavorite ? "Yes" : "No")
            infoRow("Cloud Synced", value: skin.isCloudSynced ? "Yes" : "No")
            
            if !skin.tags.isEmpty {
                infoRow("Tags", value: Array(skin.tags).sorted().joined(separator: ", "))
            }
        }
    }
    
    @ViewBuilder
    private var usageStatsContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            infoRow("Usage Count", value: "\(skin.usageCount)")
            infoRow("Recently Added", value: skin.isRecent ? "Yes" : "No")
        }
    }
    
    @ViewBuilder
    private var skinContentsView: some View {
        if isLoadingContents {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading contents...")
                    .foregroundColor(.secondary)
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(skinContents, id: \.self) { filename in
                    Text(filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 1)
                }
            }
            .frame(maxHeight: 150)
        }
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            
            Spacer()
        }
        .font(.caption)
    }
    
    private func loadSkinContents() {
        Task {
            do {
                let skinData = try Data(contentsOf: skin.fileURL)
                let unzippedData = try ZipArchive.unzip(data: skinData)
                let filenames = unzippedData.keys.sorted()
                
                await MainActor.run {
                    self.skinContents = Array(filenames)
                    self.isLoadingContents = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingContents = false
                }
            }
        }
    }
    
    private func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([skin.fileURL])
    }
    
    private func exportSkin() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "wsz")!]
        savePanel.nameFieldStringValue = "\(skin.name).wsz"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: skin.fileURL, to: url)
                } catch {
                    print("Failed to export skin: \(error)")
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Visualization Settings View
struct VisualizationSettingsView: View {
    @EnvironmentObject private var visualizationEngine: VisualizationEngine
    @EnvironmentObject private var preferencesManager: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Visualization Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                Section("Rendering") {
                    HStack {
                        Text("Quality")
                        Spacer()
                        Picker("Quality", selection: $preferencesManager.visualizationQuality) {
                            Text("Low").tag(VisualizationQuality.low)
                            Text("Medium").tag(VisualizationQuality.medium)
                            Text("High").tag(VisualizationQuality.high)
                            Text("Ultra").tag(VisualizationQuality.ultra)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Picker("Frame Rate", selection: $preferencesManager.visualizationFrameRate) {
                            Text("30 FPS").tag(30)
                            Text("60 FPS").tag(60)
                            Text("120 FPS").tag(120)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Toggle("Use Metal Performance Shaders", isOn: $preferencesManager.useMetalPerformanceShaders)
                }
                
                Section("Audio Analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sensitivity: \(visualizationEngine.sensitivity, specifier: "%.1f")")
                        Slider(value: $visualizationEngine.sensitivity, in: 0...2)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smoothing: \(visualizationEngine.smoothing, specifier: "%.1f")")
                        Slider(value: $visualizationEngine.smoothing, in: 0...1)
                    }
                }
                
                Section("Effects") {
                    Toggle("Auto-rotate modes", isOn: $preferencesManager.autoRotateModes)
                    
                    if preferencesManager.autoRotateModes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rotation interval: \(Int(preferencesManager.modeRotationInterval))s")
                            Slider(value: $preferencesManager.modeRotationInterval, in: 5...120, step: 5)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                
                Spacer()
                
                Button("Close") {
                    dismissView()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
    
    private func resetToDefaults() {
        visualizationEngine.resetToDefaults()
        preferencesManager.visualizationQuality = .high
        preferencesManager.visualizationFrameRate = 60
        preferencesManager.useMetalPerformanceShaders = true
        preferencesManager.autoRotateModes = false
        preferencesManager.modeRotationInterval = 30.0
    }
    
    private func dismissView() {
        if let window = NSApp.keyWindow {
            window.close()
        }
    }
}

/// Error Recovery View
struct ErrorRecoveryView: View {
    let error: Error
    let context: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !context.isEmpty {
                Text("Context: \(context)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Dismiss") {
                    onDismiss()
                }
            }
        }
        .padding()
        .frame(width: 350, height: 250)
    }
}

/// First Run Experience View
struct FirstRunExperienceView: View {
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var isAnimating = false
    
    private let steps = [
        ("Welcome to WinampMac", "The classic Winamp experience, reimagined for macOS", "music.note.house"),
        ("Load Your Skins", "Import .wsz files or browse our curated collection", "paintbrush"),
        ("Powerful Visualizations", "Experience music with stunning real-time graphics", "waveform"),
        ("Cloud Sync", "Keep your skins and settings synced across devices", "cloud"),
        ("Get Started", "Ready to experience the nostalgia?", "play.circle")
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            
            Spacer()
            
            // Current step content
            VStack(spacing: 20) {
                Image(systemName: steps[currentStep].2)
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                
                Text(steps[currentStep].0)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(steps[currentStep].1)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Previous") {
                        if currentStep > 0 {
                            currentStep -= 1
                        }
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
                
                if currentStep < steps.count - 1 {
                    Button("Next") {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Utility Extensions

extension UTType {
    static let wampSkin = UTType(exportedAs: "com.winamp.skin")
}

// MARK: - Demo Helper

struct DemoContentLoader {
    static func loadDemoSkins() -> [URL] {
        guard let resourcesURL = Bundle.main.url(forResource: "DemoSkins", withExtension: nil) else {
            return []
        }
        
        do {
            return try FileManager.default.contentsOfDirectory(
                at: resourcesURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "wsz" }
        } catch {
            print("Failed to load demo skins: \(error)")
            return []
        }
    }
}

// Placeholder for ZipArchive utility
struct ZipArchive {
    static func unzip(data: Data) throws -> [String: Data] {
        // This would use a real ZIP library like Compression or third-party
        // For demo purposes, return empty dictionary
        return [:]
    }
}